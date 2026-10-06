import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/error_reporter.dart';
import '../domain/kb_models.dart';

/// Loads the KB: an OTA-updated local file when it is valid and at least as new as the bundled one,
/// otherwise the bundled asset. A corrupt local file is reported and ignored, never fatal.
class KbRepository {
  KbRepository({
    required this._reporter,
    Future<File> Function()? localFile,
    Future<String> Function()? loadAsset,
  })  : _localFile = localFile ?? _defaultLocalFile,
        _loadAsset = loadAsset ?? (() => rootBundle.loadString('assets/kb/kb.json'));

  static const assetPath = 'assets/kb/kb.json';

  final ErrorReporter _reporter;
  final Future<File> Function() _localFile;
  final Future<String> Function() _loadAsset;

  static Future<File> _defaultLocalFile() async =>
      File(p.join((await getApplicationDocumentsDirectory()).path, 'kb', 'kb.json'));

  Future<KnowledgeBase> load() async {
    final bundled = KnowledgeBase.parse(await _loadAsset());

    KnowledgeBase? local;
    try {
      final f = await _localFile();
      if (await f.exists()) local = KnowledgeBase.parse(await f.readAsString());
    } catch (e, st) {
      await _reporter.record(e, st, reason: 'KB local file unusable, using bundled asset');
    }
    // After an app update the bundled KB can be newer than a stale downloaded one.
    return local != null && local.seq >= bundled.seq ? local : bundled;
  }
}
