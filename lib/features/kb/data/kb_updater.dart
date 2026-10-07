import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/error_reporter.dart';
import '../domain/kb_models.dart';

/// `kb_versions/current`, written only by the publish tool (clients can read it, never write it).
class KbPointer {
  const KbPointer({required this.seq, required this.sha256, required this.path, required this.minAppSchema});
  final int seq;
  final String sha256;
  final String path;
  final int minAppSchema;

  static KbPointer? tryParse(Map<String, Object?>? m) {
    if (m == null) return null;
    final seq = m['seq'], sha = m['sha256'], path = m['path'], schema = m['minAppSchema'];
    if (seq is! int || sha is! String || path is! String || schema is! int) return null;
    return KbPointer(seq: seq, sha256: sha.toLowerCase(), path: path, minAppSchema: schema);
  }
}

/// Where the pointer and the file come from; faked in tests.
abstract interface class KbSource {
  Future<KbPointer?> current();
  Future<Uint8List> download(String path, {required int maxBytes});
}

class FirebaseKbSource implements KbSource {
  @override
  Future<KbPointer?> current() async =>
      KbPointer.tryParse((await FirebaseFirestore.instance.doc('kb_versions/current').get()).data());

  @override
  Future<Uint8List> download(String path, {required int maxBytes}) async {
    final bytes = await FirebaseStorage.instance.ref(path).getData(maxBytes);
    if (bytes == null) throw const FormatException('empty download');
    return bytes;
  }
}

enum KbUpdateResult { updated, upToDate, skipped, failed }

/// Downloads a newer KB (Design §5.4). A file is used only if every check passes: newer `seq`, a schema this app
/// understands, SHA-256 equal to the admin-written pointer, no draft entries (outside dev), and it parses. It is written
/// next to the live file and renamed into place, so a crash or a bad file can never leave the app without a KB.
/// This is also how a bad entry is hidden without an app release: publish a new `seq` where it is not published.
class KbUpdater {
  KbUpdater({required this.source, required this.reporter, required this.currentSeq, this.allowDrafts = false, Future<File> Function()? localFile})
      : _localFile = localFile ?? _defaultFile;

  static const maxBytes = 2 * 1024 * 1024;

  final KbSource source;
  final ErrorReporter reporter;

  /// The `seq` of the KB the app is using now.
  final int Function() currentSeq;
  final bool allowDrafts;
  final Future<File> Function() _localFile;

  static Future<File> _defaultFile() async => File(p.join((await getApplicationDocumentsDirectory()).path, 'kb', 'kb.json'));

  /// Never throws: an update is an improvement, not a requirement.
  Future<KbUpdateResult> check() async {
    try {
      final pointer = await source.current();
      if (pointer == null) return KbUpdateResult.upToDate; // no pointer published, or an unreadable one
      if (pointer.seq <= currentSeq()) return KbUpdateResult.upToDate;
      if (pointer.minAppSchema > KnowledgeBase.supportedSchema) return KbUpdateResult.skipped; // this app is too old for it
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(pointer.sha256) || !_safePath(pointer.path)) {
        await reporter.record(const FormatException('bad KB pointer'), null, reason: 'KB update refused: malformed pointer');
        return KbUpdateResult.failed;
      }
      final bytes = await source.download(pointer.path, maxBytes: maxBytes);
      if (sha256.convert(bytes).toString() != pointer.sha256) {
        await reporter.record(const FormatException('sha256 mismatch'), null, reason: 'KB update refused: checksum mismatch');
        return KbUpdateResult.failed;
      }
      final text = utf8.decode(bytes);
      final kb = KnowledgeBase.parse(text);
      if (kb.seq != pointer.seq) {
        await reporter.record(FormatException('pointer seq ${pointer.seq} != file seq ${kb.seq}'), null, reason: 'KB update refused: seq mismatch');
        return KbUpdateResult.failed;
      }
      if (kb.includesDrafts && !allowDrafts) {
        await reporter.record(const FormatException('draft entries'), null, reason: 'KB update refused: contains drafts');
        return KbUpdateResult.failed;
      }
      await _swap(text);
      return KbUpdateResult.updated;
    } catch (e, st) {
      debugPrint('KB update failed: $e');
      await reporter.record(e, st, reason: 'KB update failed');
      return KbUpdateResult.failed;
    }
  }

  /// Only `kb/<name>.json` in the app's own bucket path: a pointer can never send the app elsewhere.
  static bool _safePath(String path) => RegExp(r'^kb/[A-Za-z0-9_.-]+\.json$').hasMatch(path) && !path.contains('..');

  Future<void> _swap(String text) async {
    final live = await _localFile();
    await live.parent.create(recursive: true);
    final tmp = File('${live.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(live.path); // atomic on the same filesystem
  }
}
