import 'package:sqflite/sqflite.dart';

import '../domain/diagnosis_record.dart';

class HistoryDao {
  HistoryDao(this._db);
  final Database _db;

  static const keepLast = 50;

  Future<void> insert(DiagnosisRecord r) => _db
      .insert('diagnosis_history', r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});

  Future<DiagnosisRecord?> byId(String id) async {
    final rows = await _db.query('diagnosis_history',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : DiagnosisRecord.fromMap(rows.first);
  }

  /// Most recent first.
  Future<List<DiagnosisRecord>> list({int limit = keepLast}) async {
    final rows = await _db.query('diagnosis_history',
        orderBy: 'diagnosed_at DESC, id DESC', limit: limit);
    return rows.map(DiagnosisRecord.fromMap).toList();
  }

  Future<int> count() async => Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM diagnosis_history'))!;

  /// Rows that still need a history push, a report, or a photo upload.
  Future<List<DiagnosisRecord>> pending() async {
    final rows = await _db.query('diagnosis_history',
        where: 'is_synced = 0 OR report_state = 0 OR photo_synced = 0',
        orderBy: 'diagnosed_at ASC');
    return rows.map(DiagnosisRecord.fromMap).toList();
  }

  Future<void> markSynced(String id) => _set(id, {'is_synced': 1});
  Future<void> markReported(String id) => _set(id, {'report_state': 1});
  Future<void> markPhotoSynced(String id) => _set(id, {'photo_synced': 1});

  /// Feedback re-arms the history push (`is_synced = 0`).
  Future<void> setFeedback(String id, String feedback, {String? actual}) => _set(
      id, {'feedback': feedback, 'feedback_actual': actual, 'is_synced': 0});

  Future<void> _set(String id, Map<String, Object?> values) =>
      _db.update('diagnosis_history', values, where: 'id = ?', whereArgs: [id]).then((_) {});

  /// Deletes every row beyond the newest [keep] and returns the local photo
  /// paths of the deleted rows, so the caller can delete the files.
  Future<List<String>> enforceRetention({int keep = keepLast}) =>
      _db.transaction((txn) async {
        final stale = await txn.rawQuery('''
SELECT id, photo_path FROM diagnosis_history
WHERE id NOT IN (
  SELECT id FROM diagnosis_history ORDER BY diagnosed_at DESC, id DESC LIMIT ?)''',
            [keep]);
        if (stale.isEmpty) return const <String>[];
        final ids = stale.map((r) => r['id']! as String).toList();
        final marks = List.filled(ids.length, '?').join(',');
        await txn.rawDelete(
            'DELETE FROM diagnosis_history WHERE id IN ($marks)', ids);
        return [
          for (final r in stale)
            if (r['photo_path'] != null) r['photo_path']! as String,
        ];
      });
}
