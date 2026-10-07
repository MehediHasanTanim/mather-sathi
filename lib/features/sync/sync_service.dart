import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../diagnosis/diagnosis_service.dart';
import '../history/data/history_dao.dart';
import '../history/domain/diagnosis_record.dart';
import '../profile/data/profile_store.dart';
import '../profile/domain/user_profile.dart';
import 'sync_remote.dart';
import 'week_key.dart';

abstract interface class SyncRunner {
  Future<void> flush();

  /// Stops syncing and waits for a pass in flight to finish. Used while the farmer's data is being deleted, so a
  /// running sync cannot write it back. Call [resume] afterwards.
  Future<void> suspend();
  void resume();
}

/// Reads a stored photo; null when it is gone.
typedef PhotoReader = Future<Uint8List?> Function(String path);

Future<Uint8List?> readPhotoFile(String path) async {
  final f = File(path);
  return await f.exists() ? f.readAsBytes() : null;
}

/// `report_state` values on a history row.
const kReportPending = 0;
const kReportSent = 1;
const kReportNotEligible = 2;

/// Push-only backup (Design §10.4). SQLite stays the source of truth; Firestore holds history metadata and the
/// anonymised regional reports. Every step is idempotent, so a retry after a timeout is always safe.
/// Photos go up only when the farmer turned backup or contribution on before the diagnosis was saved (`photo_synced`
/// is set at save time for everyone else), to `backups/` and/or `contrib/`.
class SyncService implements SyncRunner {
  SyncService({
    required this.history,
    required this.profile,
    required this.auth,
    required this.remote,
    required this.connectivity,
    this.opTimeout = const Duration(seconds: 10),
    this.photoTimeout = const Duration(seconds: 30),
    PhotoReader? readPhoto,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _readPhoto = readPhoto ?? readPhotoFile;

  final HistoryStore history;
  final ProfileStore profile;
  final AuthGate auth;
  final SyncRemote remote;
  final ConnectivityChecker connectivity;
  final Duration opTimeout;
  final Duration photoTimeout;
  final PhotoReader _readPhoto;
  final DateTime Function() _now;

  Future<void>? _loop; // the pass in flight, if any
  bool _again = false;
  bool _suspended = false;

  /// Pushes everything pending. Never throws. Calls made while a flush is running queue exactly one more pass.
  @override
  Future<void> flush() async {
    if (_suspended) return;
    if (_loop != null) {
      _again = true;
      return;
    }
    final run = _run();
    _loop = run;
    try {
      await run;
    } finally {
      _loop = null;
    }
  }

  Future<void> _run() async {
    do {
      _again = false;
      await _flushOnce();
    } while (_again && !_suspended);
  }

  @override
  Future<void> suspend() async {
    _suspended = true;
    await _loop;
  }

  @override
  void resume() => _suspended = false;

  Future<void> _flushOnce() async {
    try {
      if (!await connectivity.isOnline()) return;
      final uid = await auth.ensureSignedIn(); // writes are rejected without auth
      final p = await profile.load() ?? UserProfile.initial;
      for (final r in await history.pending()) {
        if (_suspended) return;
        await _syncRow(uid, p, r);
      }
    } catch (e) {
      // Offline, no auth, or a read error: leave everything pending for the next trigger.
      debugPrint('sync pass failed: $e');
    }
  }

  Future<void> _syncRow(String uid, UserProfile p, DiagnosisRecord r) async {
    try {
      // 1. history doc (no photo bytes)
      if (!r.isSynced) {
        await remote.setHistory(uid, r.id, r.toFirestore()).timeout(opTimeout);
        await history.markSynced(r);
      }
      // 2. regional report: eligibility was decided at save time; consent is re-checked now
      if (r.reportState == kReportPending) {
        final report = _buildReport(uid, r);
        if (!p.shareReports || report == null) {
          await history.setReportState(r.id, kReportNotEligible);
        } else {
          try {
            await remote.setReport(report.$1, report.$2).timeout(opTimeout);
          } on SyncDenied {
            // Already reported this week: the create-only rules turned the repeat into a denial.
          }
          await history.markReported(r.id);
        }
      }
      // 3. photo, only with explicit consent
      if (!r.photoSynced && (p.photoBackup || p.photoContribute)) {
        await _uploadPhoto(uid, p, r);
        await history.markPhotoSynced(r.id);
      }
    } catch (e) {
      // One bad row (timeout, offline) must not block the others; it stays pending.
      debugPrint('sync of ${r.id} failed: $e');
    }
  }

  Future<void> _uploadPhoto(String uid, UserProfile p, DiagnosisRecord r) async {
    final path = r.photoPath;
    final bytes = path == null ? null : await _readPhoto(path);
    if (bytes == null) return; // the file is gone: nothing to upload, and nothing to retry
    if (p.photoBackup) {
      final target = 'backups/$uid/${r.id}.jpg';
      await remote.uploadPhoto(target, bytes).timeout(photoTimeout);
      await remote.setPhotoUrl(uid, r.id, target).timeout(opTimeout);
    }
    if (p.photoContribute) {
      try {
        await remote.uploadPhoto('contrib/$uid/${r.id}.jpg', bytes).timeout(photoTimeout);
      } on SyncDenied {
        // contrib/ is write-once: a retry after a lost response finds the object already there.
      }
    }
  }

  /// (doc id, fields) for `reports/`, or null when this row cannot be reported.
  (String, Map<String, Object?>)? _buildReport(String uid, DiagnosisRecord r) {
    final disease = r.diseaseId;
    if (disease == null || r.district == null || r.upazila == null || r.cropType == 'other') return null;
    final week = weekKey(r.diagnosedAt);
    return (
      '${uid}_${week}_${r.cropType}_$disease',
      {
        'uid': uid,
        'district': r.district,
        'upazila': r.upazila,
        'crop': r.cropType,
        'diseaseId': disease,
        'week': week,
        'expireAt': _now().toUtc().add(const Duration(days: 30)), // Firestore TTL policy
      },
    );
  }
}
