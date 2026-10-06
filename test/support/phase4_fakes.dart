import 'dart:async';
import 'dart:typed_data';

import 'package:mather_sathi/features/history/data/history_dao.dart';
import 'package:mather_sathi/features/history/data/photo_store.dart';
import 'package:mather_sathi/features/history/domain/diagnosis_record.dart';
import 'package:mather_sathi/features/tts/tts_engine.dart';

/// In-memory HistoryStore with the same ordering and retention rules as the SQLite DAO (which has its own ffi tests).
class InMemoryHistoryStore implements HistoryStore {
  final rows = <String, DiagnosisRecord>{};

  List<DiagnosisRecord> get _sorted => rows.values.toList()
    ..sort((a, b) {
      final c = b.diagnosedAt.compareTo(a.diagnosedAt);
      return c != 0 ? c : b.id.compareTo(a.id);
    });

  @override
  Future<void> insert(DiagnosisRecord r) async => rows[r.id] = r;
  @override
  Future<DiagnosisRecord?> byId(String id) async => rows[id];
  @override
  Future<List<DiagnosisRecord>> list({int limit = 50}) async => _sorted.take(limit).toList();
  @override
  Future<int> count() async => rows.length;
  @override
  Future<List<DiagnosisRecord>> pending() async => rows.values.where((r) => !r.isSynced || r.reportState == 0 || !r.photoSynced).toList();
  @override
  Future<void> markSynced(DiagnosisRecord pushed) async {
    final cur = rows[pushed.id];
    if (cur != null && cur.feedback == pushed.feedback && cur.feedbackActual == pushed.feedbackActual) _upd(pushed.id, isSynced: true);
  }
  @override
  Future<void> markReported(String id) async => _upd(id, reportState: 1);
  @override
  Future<void> setReportState(String id, int state) async => _upd(id, reportState: state);
  @override
  Future<void> markPhotoSynced(String id) async => _upd(id, photoSynced: true);
  @override
  Future<void> setFeedback(String id, String feedback, {String? actual}) async =>
      _upd(id, feedback: feedback, actual: actual, isSynced: false, setFeedback: true);

  void _upd(String id, {bool? isSynced, int? reportState, bool? photoSynced, String? feedback, String? actual, bool setFeedback = false}) {
    final r = rows[id]!;
    rows[id] = DiagnosisRecord(
      id: r.id, cropType: r.cropType, cropLabel: r.cropLabel, diseaseId: r.diseaseId, diseaseNameBn: r.diseaseNameBn,
      kbSeq: r.kbSeq, adviceJson: r.adviceJson, confidence: r.confidence, source: r.source, photoPath: r.photoPath,
      diagnosedAt: r.diagnosedAt, district: r.district, upazila: r.upazila,
      feedback: setFeedback ? feedback : r.feedback, feedbackActual: setFeedback ? actual : r.feedbackActual,
      isSynced: isSynced ?? r.isSynced, reportState: reportState ?? r.reportState, photoSynced: photoSynced ?? r.photoSynced,
    );
  }

  @override
  Future<List<String>> enforceRetention({int keep = 50}) async {
    final stale = _sorted.skip(keep).toList();
    for (final r in stale) {
      rows.remove(r.id);
    }
    return [for (final r in stale) if (r.photoPath != null) r.photoPath!];
  }
}

class FakePhotoStore implements PhotoStore {
  final files = <String, Uint8List>{};
  final deleted = <String>[];
  bool failSave = false;

  @override
  Future<String> save(String id, Uint8List jpeg) async {
    if (failSave) throw Exception('disk full');
    final path = '/photos/$id.jpg';
    files[path] = jpeg;
    return path;
  }

  @override
  Future<void> delete(Iterable<String> paths) async {
    for (final p in paths) {
      files.remove(p);
      deleted.add(p);
    }
  }
}

/// TTS engine whose speech finishes only when the test says so, or when stop() is called.
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({this.installed = true});
  bool installed;
  final spoken = <String>[];
  int active = 0;
  int maxActive = 0;
  double? rate;
  Completer<void>? _current;

  @override
  Future<bool> isBanglaInstalled() async => installed;

  @override
  Future<void> configure({required double rate}) async => this.rate = rate;

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    active++;
    if (active > maxActive) maxActive = active;
    final c = Completer<void>();
    _current = c;
    return c.future.whenComplete(() => active--);
  }

  /// The current chunk finished naturally.
  void finishChunk() {
    final c = _current;
    _current = null;
    c?.complete();
  }

  @override
  Future<void> stop() async {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete();
  }
}
