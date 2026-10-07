import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// The remote rejected a write on purpose (Firestore rules: `permission-denied`).
class SyncDenied implements Exception {
  const SyncDenied();
}

/// Firestore writes used by sync; faked in tests.
abstract interface class SyncRemote {
  /// Writes `users/{uid}/history/{id}`, merging into the existing doc so fields owned by the server or by the photo
  /// step (`photoUrl`) survive a feedback re-push. Safe to repeat.
  Future<void> setHistory(String uid, String id, Map<String, Object?> data);

  /// Points the history doc at its backed-up photo (the Storage path, never a download URL).
  Future<void> setPhotoUrl(String uid, String id, String storagePath);

  /// Uploads a prepared JPEG to [storagePath]. Throws [SyncDenied] when the rules refuse it, which for the write-once
  /// `contrib/` folder means "already uploaded".
  Future<void> uploadPhoto(String storagePath, Uint8List jpeg);

  /// Creates `reports/{docId}`. The doc id is deterministic and the rules only allow create, so a repeat
  /// in the same week is denied: that surfaces as [SyncDenied] and means "already reported".
  Future<void> setReport(String docId, Map<String, Object?> data);
}

class FirestoreSyncRemote implements SyncRemote {
  FirestoreSyncRemote([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<void> setHistory(String uid, String id, Map<String, Object?> data) =>
      _db.doc('users/$uid/history/$id').set(data, SetOptions(merge: true));

  @override
  Future<void> setPhotoUrl(String uid, String id, String storagePath) =>
      _db.doc('users/$uid/history/$id').set({'photoUrl': storagePath}, SetOptions(merge: true));

  @override
  Future<void> uploadPhoto(String storagePath, Uint8List jpeg) async {
    try {
      await FirebaseStorage.instance.ref(storagePath).putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized') throw const SyncDenied(); // Storage's name for a rules denial
      rethrow;
    }
  }

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
