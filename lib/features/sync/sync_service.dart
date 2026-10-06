import 'dart:async';

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
}

/// `report_state` values on a history row.
const kReportPending = 0;
const kReportSent = 1;
const kReportNotEligible = 2;

/// Push-only backup (Design §10.4). SQLite stays the source of truth; Firestore holds history metadata and the
/// anonymised regional reports. Every step is idempotent, so a retry after a timeout is always safe.
/// Photo upload (backup/contribution) is added in task 8.2.
class SyncService implements SyncRunner {
  SyncService({
    required this.history,
    required this.profile,
    required this.auth,
    required this.remote,
    required this.connectivity,
    this.opTimeout = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final HistoryStore history;
  final ProfileStore profile;
  final AuthGate auth;
  final SyncRemote remote;
  final ConnectivityChecker connectivity;
  final Duration opTimeout;
  final DateTime Function() _now;

  bool _running = false;
  bool _again = false;

  /// Pushes everything pending. Never throws. Calls made while a flush is running queue exactly one more pass.
  @override
  Future<void> flush() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _flushOnce();
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _flushOnce() async {
    try {
      if (!await connectivity.isOnline()) return;
      final uid = await auth.ensureSignedIn(); // writes are rejected without auth
      final p = await profile.load() ?? UserProfile.initial;
      for (final r in await history.pending()) {
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
    } catch (e) {
      // One bad row (timeout, offline) must not block the others; it stays pending.
      debugPrint('sync of ${r.id} failed: $e');
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
