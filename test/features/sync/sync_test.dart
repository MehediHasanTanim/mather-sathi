import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/features/history/domain/diagnosis_record.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/features/sync/sync_remote.dart';
import 'package:mather_sathi/features/sync/sync_service.dart';
import 'package:mather_sathi/features/sync/week_key.dart';

import '../../support/diagnosis_fakes.dart';
import '../../support/fakes.dart';
import '../../support/phase4_fakes.dart';

class FakeRemote implements SyncRemote {
  final histories = <String, Map<String, Object?>>{};
  final reports = <String, Map<String, Object?>>{};
  Object? failHistory;
  Object? failReport;
  Completer<void>? hangHistory;
  int historyWrites = 0;
  void Function()? duringHistory;

  @override
  Future<void> setHistory(String uid, String id, Map<String, Object?> data) async {
    historyWrites++;
    duringHistory?.call();
    if (hangHistory != null) await hangHistory!.future;
    if (failHistory != null) throw failHistory!;
    histories['$uid/$id'] = data;
  }

  @override
  Future<void> setReport(String docId, Map<String, Object?> data) async {
    if (failReport != null) throw failReport!;
    if (reports.containsKey(docId)) throw const SyncDenied(); // create-only rules deny a repeat
    reports[docId] = data;
  }
}

DiagnosisRecord rec(String id, {
  String? disease = 'rice_blast', String crop = 'rice', String? district = 'dhaka', String? upazila = '5',
  DateTime? at, bool synced = false, int reportState = 0, String? feedback,
}) =>
    DiagnosisRecord(
      id: id, cropType: crop, diseaseId: disease, source: 'cloud', confidence: 'high', photoPath: '/p/$id.jpg',
      diagnosedAt: at ?? DateTime.utc(2026, 10, 6, 10), district: district, upazila: upazila,
      isSynced: synced, reportState: reportState, feedback: feedback, photoSynced: true,
    );

class Env {
  Env({UserProfile profile = const UserProfile(district: 'dhaka', upazila: '5', onboardingDone: true), bool online = true}) {
    connectivity = FakeConnectivity(online);
    sync = SyncService(
      history: store, profile: FakeProfileStore(profile), auth: auth, remote: remote, connectivity: connectivity,
      now: () => DateTime.utc(2026, 10, 6),
    );
  }
  final store = InMemoryHistoryStore();
  final remote = FakeRemote();
  final auth = FakeAuth();
  late final FakeConnectivity connectivity;
  late final SyncService sync;
}

void main() {
  group('weekKey (ISO week, Dhaka time)', () {
    test('typical dates', () {
      expect(weekKey(DateTime.utc(2026, 10, 6, 10)), '2026-W41');
      expect(weekKey(DateTime.utc(2026, 1, 1, 6)), '2026-W01');
    });
    test('year boundaries follow the ISO rule', () {
      expect(weekKey(DateTime.utc(2025, 12, 29, 6)), '2026-W01', reason: 'Monday of the week containing 2026-01-01');
      expect(weekKey(DateTime.utc(2021, 1, 3, 6)), '2020-W53');
      expect(weekKey(DateTime.utc(2024, 12, 30, 6)), '2025-W01');
    });
    test('the week rolls at midnight in Dhaka (18:00 UTC), not UTC midnight', () {
      expect(weekKey(DateTime.utc(2026, 10, 4, 17, 59)), '2026-W40'); // Sunday 23:59 Dhaka
      expect(weekKey(DateTime.utc(2026, 10, 4, 18, 0)), '2026-W41'); // Monday 00:00 Dhaka
    });
  });

  group('SyncService', () {
    test('offline or not signed in: nothing is sent and nothing throws', () async {
      final off = Env(online: false)..store.rows['a'] = rec('a');
      await off.sync.flush();
      expect(off.remote.historyWrites, 0);

      final noAuth = Env();
      noAuth.store.rows['a'] = rec('a');
      noAuth.auth.throws = Exception('no network');
      await noAuth.sync.flush();
      expect(noAuth.remote.historyWrites, 0);
      expect(noAuth.store.rows['a']!.isSynced, isFalse);
    });

    test('pushes the history doc (metadata only) and marks the row synced', () async {
      final e = Env()..store.rows['a'] = rec('a');
      await e.sync.flush();
      final doc = e.remote.histories['test-uid/a']!;
      expect(doc['disease_id'], 'rice_blast');
      expect(doc.keys.toSet().intersection({'photo_path', 'is_synced', 'report_state', 'photo_synced'}), isEmpty, reason: 'no photo path or local flags');
      expect(e.store.rows['a']!.isSynced, isTrue);
      expect(e.auth.calls, 1);
    });

    test('pushes a regional report with a deterministic id and a 30-day TTL', () async {
      final e = Env()..store.rows['a'] = rec('a');
      await e.sync.flush();
      final r = e.remote.reports['test-uid_2026-W41_rice_rice_blast']!;
      expect(r, {
        'uid': 'test-uid', 'district': 'dhaka', 'upazila': '5', 'crop': 'rice', 'diseaseId': 'rice_blast',
        'week': '2026-W41', 'expireAt': DateTime.utc(2026, 11, 5),
      });
      expect(e.store.rows['a']!.reportState, kReportSent);
    });

    test('two diagnoses of the same disease in one week produce one report doc', () async {
      final e = Env()
        ..store.rows['a'] = rec('a')
        ..store.rows['b'] = rec('b', at: DateTime.utc(2026, 10, 7, 10));
      await e.sync.flush();
      expect(e.remote.reports, hasLength(1));
      expect(e.store.rows['b']!.reportState, kReportSent, reason: 'a denied repeat counts as already reported');
      expect(e.store.rows['a']!.reportState, kReportSent);
    });

    test('a different week or disease is a new report', () async {
      final e = Env()
        ..store.rows['a'] = rec('a')
        ..store.rows['b'] = rec('b', at: DateTime.utc(2026, 10, 14, 10))
        ..store.rows['c'] = rec('c', disease: 'rice_brown_spot');
      await e.sync.flush();
      expect(e.remote.reports, hasLength(3));
    });

    test('consent turned off after saving: the report is skipped for good', () async {
      final e = Env(profile: const UserProfile(district: 'dhaka', shareReports: false, onboardingDone: true))
        ..store.rows['a'] = rec('a');
      await e.sync.flush();
      expect(e.remote.reports, isEmpty);
      expect(e.store.rows['a']!.reportState, kReportNotEligible);
      expect(e.remote.histories, hasLength(1), reason: 'history itself is still backed up');
    });

    test('rows that cannot be reported are marked not eligible', () async {
      final e = Env()
        ..store.rows['other'] = rec('other', crop: 'other', disease: 'general_advice')
        ..store.rows['nodistrict'] = rec('nodistrict', district: null)
        ..store.rows['nodisease'] = rec('nodisease', disease: null);
      await e.sync.flush();
      expect(e.remote.reports, isEmpty);
      expect(e.store.rows.values.every((r) => r.reportState == kReportNotEligible), isTrue);
    });

    test('a failed row stays pending, other rows still sync, and a retry completes it', () async {
      final e = Env()
        ..store.rows['a'] = rec('a', at: DateTime.utc(2026, 10, 6, 9))
        ..store.rows['b'] = rec('b', at: DateTime.utc(2026, 10, 6, 10), disease: 'rice_brown_spot');
      e.remote.failReport = Exception('flaky');
      await e.sync.flush();
      expect(e.store.rows['a']!.isSynced, isTrue);
      expect(e.store.rows['a']!.reportState, kReportPending);
      expect(e.store.rows['b']!.isSynced, isTrue, reason: 'one bad row does not block the next');

      e.remote.failReport = null;
      await e.sync.flush();
      expect(e.store.rows.values.every((r) => r.reportState == kReportSent), isTrue);
      expect(e.remote.reports, hasLength(2));
    });

    test('a history failure leaves the row fully pending; retry is harmless (idempotent)', () async {
      final e = Env()..store.rows['a'] = rec('a');
      e.remote.failHistory = Exception('offline');
      await e.sync.flush();
      expect(e.store.rows['a']!.isSynced, isFalse);
      expect(e.remote.reports, isEmpty);
      e.remote.failHistory = null;
      await e.sync.flush();
      await e.sync.flush();
      expect(e.store.rows['a']!.isSynced, isTrue);
      expect(e.remote.reports, hasLength(1));
    });

    test('a hung write times out after 10 s and leaves the row pending', () {
      fakeAsync((fake) {
        final e = Env()..store.rows['a'] = rec('a');
        e.remote.hangHistory = Completer<void>();
        var done = false;
        e.sync.flush().then((_) => done = true);
        fake.elapse(const Duration(seconds: 9));
        expect(done, isFalse);
        fake.elapse(const Duration(seconds: 2));
        expect(done, isTrue);
        expect(e.store.rows['a']!.isSynced, isFalse);
      });
    });

    test('feedback given while the push was in flight is not lost', () async {
      final e = Env()..store.rows['a'] = rec('a', reportState: kReportSent);
      e.remote.duringHistory = () => e.store.setFeedback('a', 'incorrect', actual: 'rice_brown_spot');
      await e.sync.flush();
      expect(e.store.rows['a']!.feedback, 'incorrect');
      expect(e.store.rows['a']!.isSynced, isFalse, reason: 'the edit made mid-push must be sent by the next flush');
      e.remote.duringHistory = null;
      await e.sync.flush();
      expect(e.store.rows['a']!.isSynced, isTrue);
      expect(e.remote.histories['test-uid/a']!['feedback'], 'incorrect');
    });

    test('feedback after a sync re-arms and is pushed again', () async {
      final e = Env()..store.rows['a'] = rec('a');
      await e.sync.flush();
      await e.store.setFeedback('a', 'correct');
      await e.sync.flush();
      expect(e.remote.histories['test-uid/a']!['feedback'], 'correct');
      expect(e.remote.historyWrites, 2);
    });

    test('flush calls during a running flush queue exactly one extra pass', () async {
      final e = Env()..store.rows['a'] = rec('a');
      final gate = Completer<void>();
      e.remote.hangHistory = gate;
      final first = e.sync.flush();
      await Future<void>.delayed(Duration.zero);
      final second = e.sync.flush();
      final third = e.sync.flush();
      e.store.rows['b'] = rec('b', disease: 'rice_brown_spot'); // arrives while the first pass runs
      e.remote.hangHistory = null;
      gate.complete();
      await Future.wait([first, second, third]);
      expect(e.store.rows.values.every((r) => r.isSynced), isTrue, reason: 'the queued pass picked up the new row');
    });

    test('a synced row with everything done is not touched again', () async {
      final e = Env()..store.rows['a'] = rec('a', synced: true, reportState: kReportSent);
      await e.sync.flush();
      expect(e.remote.historyWrites, 0);
      expect(e.remote.reports, isEmpty);
    });
  });
}
