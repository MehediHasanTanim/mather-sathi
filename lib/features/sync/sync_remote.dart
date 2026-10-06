import 'package:cloud_firestore/cloud_firestore.dart';

/// The remote rejected a write on purpose (Firestore rules: `permission-denied`).
class SyncDenied implements Exception {
  const SyncDenied();
}

/// Firestore writes used by sync; faked in tests.
abstract interface class SyncRemote {
  /// Overwrites `users/{uid}/history/{id}`. Safe to repeat.
  Future<void> setHistory(String uid, String id, Map<String, Object?> data);

  /// Creates `reports/{docId}`. The doc id is deterministic and the rules only allow create, so a repeat
  /// in the same week is denied: that surfaces as [SyncDenied] and means "already reported".
  Future<void> setReport(String docId, Map<String, Object?> data);
}

class FirestoreSyncRemote implements SyncRemote {
  FirestoreSyncRemote([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<void> setHistory(String uid, String id, Map<String, Object?> data) =>
      _db.doc('users/$uid/history/$id').set(data);

  @override
  Future<void> setReport(String docId, Map<String, Object?> data) async {
    try {
      // The rules require createdAt == request.time and an exact field list (see firebase/firestore.rules).
      await _db.doc('reports/$docId').set({...data, 'createdAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const SyncDenied();
      rethrow;
    }
  }
}
