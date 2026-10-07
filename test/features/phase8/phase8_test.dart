import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mather_sathi/core/analytics/analytics.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/core/l10n/gen/app_localizations_bn.dart';
import 'package:mather_sathi/features/expert/expert_providers.dart';
import 'package:mather_sathi/features/expert/helpline_schedule.dart';
import 'package:mather_sathi/features/history/domain/diagnosis_record.dart';
import 'package:mather_sathi/features/history/providers/history_provider.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/kb/kb_provider.dart';
import 'package:mather_sathi/features/privacy/data_deletion.dart';
import 'package:mather_sathi/features/settings/providers/app_info.dart';
import 'package:mather_sathi/features/share/share_content.dart';
import 'package:mather_sathi/features/share/share_service.dart';
import 'package:mather_sathi/features/tts/tts_controller.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../../support/diagnosis_fakes.dart';
import '../../support/fakes.dart';
import '../../support/phase4_fakes.dart';
import '../../support/phase7_fakes.dart';
import '../../support/phase8_fakes.dart';
import '../../support/pump_app.dart';
import '../result/result_screen_test.dart' show entry, kbOf, rec;

class _Kb extends KbNotifier {
  _Kb(this.kb);
  final KnowledgeBase kb;
  @override
  Future<KnowledgeBase> build() async => kb;
}

void main() {
  final l = AppLocalizationsBn();

  group('HelplineSchedule (task 8.4)', () {
    const text = 'Sat,Sun,Mon,Tue,Wed,Thu 09:00-17:00';
    // 2026-10-04 is a Sunday. Dhaka is UTC+6, so 09:00 Dhaka = 03:00 UTC.
    DateTime dhaka(int day, int h, int m) => DateTime.utc(2026, 10, day, h - 6, m);

    test('open during the hours on a working day, in Dhaka time whatever the input zone', () {
      final s = HelplineSchedule.parse(text)!;
      expect(s.isOpenAt(dhaka(4, 9, 0)), isTrue);
      expect(s.isOpenAt(dhaka(4, 16, 59)), isTrue);
      expect(s.isOpenAt(dhaka(4, 17, 0)), isFalse, reason: 'closing time is exclusive');
      expect(s.isOpenAt(dhaka(4, 8, 59)), isFalse);
      expect(s.isOpenAt(DateTime.utc(2026, 10, 4, 3, 0).toLocal()), isTrue, reason: 'a local-time instant is converted correctly');
    });

    test('closed on days not listed (Friday)', () {
      final s = HelplineSchedule.parse(text)!;
      expect(DateTime.utc(2026, 10, 9).weekday, DateTime.friday);
      expect(s.isOpenAt(dhaka(9, 12, 0)), isFalse);
    });

    test('the Dhaka day, not the UTC day, decides: Thursday 23:30 UTC is Friday in Dhaka', () {
      final s = HelplineSchedule.parse('Fri 00:00-23:59')!;
      expect(s.isOpenAt(DateTime.utc(2026, 10, 8, 20, 0)), isTrue); // Fri 02:00 Dhaka
      expect(s.isOpenAt(DateTime.utc(2026, 10, 8, 10, 0)), isFalse); // Thu 16:00 Dhaka
    });

    test('anything unreadable is null (unknown), never a guess', () {
      for (final bad in ['', 'open', 'Sat 09:00', 'Sat 17:00-09:00', 'Xyz 09:00-17:00', 'Sat 09:61-17:00', 'Sat 09:00-25:00', 'Sat,, 09:00-17:00']) {
        expect(HelplineSchedule.parse(bad), isNull, reason: bad);
      }
    });
  });

  group('expert screen (task 8.4)', () {
    final analytics = RecordingAnalytics();
    Future<FakeDialer> open(WidgetTester tester, {Map<String, Object?> flags = const {}, DateTime? now, bool dialWorks = true}) async {
      final dialer = FakeDialer()..works = dialWorks;
      await pumpApp(tester, saved: doneProfile, overrides: [
        dialerProvider.overrideWithValue(dialer),
        analyticsProvider.overrideWithValue(analytics),
        remoteFlagOverridesProvider.overrideWithValue(flags),
        clockProvider.overrideWithValue(() => now ?? DateTime.utc(2026, 10, 4, 5)),
      ]);
      tester.view.physicalSize = const Size(1080, 6000);
      await tester.tap(find.text('সেটিংস'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('settings_expert')));
      await tester.tap(find.byKey(const Key('settings_expert')));
      await tester.pumpAndSettle();
      return dialer;
    }

    testWidgets('shows the configured number, hours text and note; no badge without a schedule', (tester) async {
      await open(tester, flags: {'helpline_number': '16123', 'helpline_hours_text': 'সকাল ৯টা–বিকাল ৫টা', 'helpline_note': 'প্রতি মিনিটে খরচ প্রযোজ্য'});
      expect(find.byKey(const Key('helpline_number')), findsOneWidget);
      expect(find.textContaining('সকাল ৯টা–বিকাল ৫টা'), findsOneWidget);
      expect(find.text('প্রতি মিনিটে খরচ প্রযোজ্য'), findsOneWidget);
      expect(find.byKey(const Key('helpline_open')), findsNothing);
      expect(find.byKey(const Key('helpline_closed')), findsNothing);
    });

    testWidgets('open badge inside the hours', (tester) async {
      await open(tester, flags: {'helpline_schedule': 'Sat,Sun,Mon,Tue,Wed,Thu 09:00-17:00'}, now: DateTime.utc(2026, 10, 4, 5)); // Sun 11:00 Dhaka
      expect(find.byKey(const Key('helpline_open')), findsOneWidget);
      expect(find.text('এখন খোলা'), findsOneWidget);
    });

    testWidgets('closed badge outside the hours, and the call button still works', (tester) async {
      final dialer = await open(tester, flags: {'helpline_schedule': 'Sat,Sun,Mon,Tue,Wed,Thu 09:00-17:00'}, now: DateTime.utc(2026, 10, 9, 5)); // Friday
      expect(find.byKey(const Key('helpline_closed')), findsOneWidget);
      expect(find.text('এখন বন্ধ'), findsOneWidget);
      await tester.tap(find.byKey(const Key('helpline_call')));
      await tester.pumpAndSettle();
      expect(dialer.dialed, ['16123'], reason: 'the dialer gets the plain Latin-digit number');
      expect(analytics.names, contains('expert_call_tapped'));
    });

    testWidgets('hours come from Remote Config: a different value changes the screen without a release', (tester) async {
      await open(tester, flags: {'helpline_number': '16999', 'helpline_hours_text': 'নতুন সময়'});
      expect(find.textContaining('নতুন সময়'), findsOneWidget);
      await tester.tap(find.byKey(const Key('helpline_call')));
      await tester.pumpAndSettle();
    });

    testWidgets('when no dialer opens, the farmer is shown the number', (tester) async {
      await open(tester, dialWorks: false);
      await tester.tap(find.byKey(const Key('helpline_call')));
      await tester.pumpAndSettle();
      expect(find.textContaining('নম্বরটি হলো 16123'), findsOneWidget);
    });
  });

  group('settings (task 8.1)', () {
    late FakeTopicSync topics;
    late FakeTtsEngine tts;

    Future<FakeProfileStore> open(WidgetTester tester, {List overrides = const []}) async {
      topics = FakeTopicSync();
      tts = FakeTtsEngine();
      final store = await pumpApp(tester, saved: doneProfile, topics: topics, overrides: [
        ttsEngineProvider.overrideWithValue(tts),
        appVersionProvider.overrideWith((_) async => '1.2.3+4'),
        kbProvider.overrideWith(() => _Kb(kbOf([entry('rice_blast', 'rice', 'ধানের ব্লাস্ট রোগ', 'high')], seq: 9))),
        ...overrides,
      ]);
      tester.view.physicalSize = const Size(1080, 6000);
      await tester.tap(find.text('সেটিংস'));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('the toggles persist and sync topics straight away', (tester) async {
      final store = await open(tester);
      await tester.tap(find.byKey(const Key('settings_notifications')));
      await tester.pumpAndSettle();
      expect(store.saved!.notifications, isFalse);
      expect(topics.synced.last.notifications, isFalse, reason: 'turning notifications off drops the topic');

      await tester.tap(find.byKey(const Key('settings_reports')));
      await tester.tap(find.byKey(const Key('settings_backup')));
      await tester.tap(find.byKey(const Key('settings_contribute')));
      await tester.pumpAndSettle();
      expect([store.saved!.shareReports, store.saved!.photoBackup, store.saved!.photoContribute], [false, true, true]);
    });

    testWidgets('photo backup and contribution start off for a default profile, reports on', (tester) async {
      await open(tester);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('settings_backup'))).value, isFalse);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('settings_contribute'))).value, isFalse);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('settings_reports'))).value, isTrue);
    });

    testWidgets('changing the default crop persists', (tester) async {
      final store = await open(tester);
      await tester.ensureVisible(find.byKey(const Key('settings_crop_potato')));
      await tester.tap(find.byKey(const Key('settings_crop_potato')));
      await tester.pumpAndSettle();
      expect(store.saved!.defaultCrop, 'potato');
    });

    testWidgets('changing the district clears the old upazila, asks for a new one and switches the topic', (tester) async {
      final store = await open(tester);
      await tester.tap(find.byKey(const Key('settings_district')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Gazipur');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)).first);
      await tester.pumpAndSettle();
      expect(store.saved!.district, 'gazipur');
      expect(store.saved!.upazila, isNull, reason: 'the upazila belonged to the old district');
      expect(topics.synced.last.district, 'gazipur');
      // The upazila picker opened by itself: choose the first one.
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)).first);
      await tester.pumpAndSettle();
      expect(store.saved!.upazila, isNotNull);
    });

    testWidgets('speech speed persists, applies to the very next playback and plays a sample', (tester) async {
      final store = await open(tester);
      await tester.tap(find.byKey(const Key('tts_fast')));
      await tester.pumpAndSettle();
      expect(store.saved!.ttsSpeed, 'fast');
      expect(tts.rate, RemoteFlags.defaults.ttsRateFast);
      expect(tts.spoken.single, l.ttsTrySample);

      await tester.tap(find.byKey(const Key('tts_slow')));
      await tester.pumpAndSettle();
      expect(tts.rate, RemoteFlags.defaults.ttsRateSlow);
    });

    testWidgets('about shows the app and knowledge-base versions', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.byKey(const Key('about_app')));
      expect(find.text('অ্যাপের সংস্করণ: 1.2.3+4'), findsOneWidget);
      expect(find.byKey(const Key('about_kb')), findsOneWidget);
    });
  });

  group('delete history (task 8.3)', () {
    late InMemoryHistoryStore history;
    late FakePhotoStore photos;
    late FakeRemoteEraser eraser;
    late RecordingSync sync;

    DataDeletion service() => DataDeletion(sync: sync, auth: FakeAuth(), remote: eraser, history: history, photos: photos);

    void seed() {
      history = InMemoryHistoryStore()
        ..rows['a'] = DiagnosisRecord(id: 'a', cropType: 'rice', source: 'cloud', diagnosedAt: DateTime.utc(2026), photoPath: '/photos/a.jpg')
        ..rows['b'] = DiagnosisRecord(id: 'b', cropType: 'rice', source: 'cloud', diagnosedAt: DateTime.utc(2026, 2), photoPath: '/photos/b.jpg');
      photos = FakePhotoStore()..files['/photos/a.jpg'] = Uint8List(1)..files['/photos/b.jpg'] = Uint8List(1);
      eraser = FakeRemoteEraser();
      sync = RecordingSync();
    }

    test('the server is asked first, then rows and photo files are removed, with sync stopped throughout', () async {
      seed();
      eraser.during = () {
        expect(history.rows, hasLength(2), reason: 'local data is still there while the server call runs');
        expect(sync.log, ['suspend']);
      };
      await service().run();
      expect(eraser.calls, 1);
      expect(history.rows, isEmpty);
      expect(photos.files, isEmpty);
      expect(sync.log, ['suspend', 'resume']);
    });

    test('when the server cannot confirm, nothing is wiped locally and sync resumes', () async {
      seed();
      eraser.throws = Exception('offline');
      await expectLater(service().run(), throwsA(isA<DeletionFailed>()));
      expect(history.rows, hasLength(2));
      expect(photos.files, hasLength(2));
      expect(sync.log, ['suspend', 'resume']);
    });

    test('a sign-in failure is also reported as a failed deletion', () async {
      seed();
      final svc = DataDeletion(sync: sync, auth: FakeAuth()..throws = Exception('no auth'), remote: eraser, history: history, photos: photos);
      await expectLater(svc.run(), throwsA(isA<DeletionFailed>()));
      expect(eraser.calls, 0);
      expect(history.rows, hasLength(2));
    });

    Future<void> openSettings(WidgetTester tester) async {
      await pumpApp(tester, saved: doneProfile, overrides: [
        historyDaoProvider.overrideWithValue(history),
        dataDeletionProvider.overrideWithValue(service()),
      ]);
      tester.view.physicalSize = const Size(1080, 6000);
      await tester.tap(find.text('সেটিংস'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirming deletes and says so', (tester) async {
      seed();
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings_delete')));
      await tester.pumpAndSettle();
      expect(find.text('সব ইতিহাস মুছবেন?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();
      expect(history.rows, isEmpty);
      expect(find.text('ইতিহাস মুছে ফেলা হয়েছে।'), findsOneWidget);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      seed();
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_cancel')));
      await tester.pumpAndSettle();
      expect(eraser.calls, 0);
      expect(history.rows, hasLength(2));
    });

    testWidgets('a failure is reported honestly and the data stays', (tester) async {
      seed();
      eraser.throws = Exception('offline');
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('মোছা যায়নি'), findsOneWidget);
      expect(find.text('ইতিহাস মুছে ফেলা হয়েছে।'), findsNothing);
      expect(history.rows, hasLength(2));
    });
  });

  group('share (task 8.5)', () {
    final kb = kbOf([entry('rice_blast', 'rice', 'ধানের ব্লাস্ট রোগ', 'high')]);
    final shareAnalytics = RecordingAnalytics();

    test('text carries only KB content: name, first step, the first medicine, disclaimer', () {
      final text = ShareContent.fromDisease(l, kb['rice_blast']!).toText(l);
      expect(text, contains('🌿 ধানের ব্লাস্ট রোগ'));
      expect(text, contains('করণীয়: এখনই করুন ১'));
      expect(text, contains('ওষুধ ক — ২ গ্রাম'));
      expect(text, contains(l.aiDisclaimer));
      expect(text, contains(l.shareCardTagline));
    });

    test('a draft (unreviewed) entry never shares a medicine line', () {
      final draft = kbOf([entry('rice_blast', 'rice', 'ধানের ব্লাস্ট রোগ', 'high', status: 'draft')], drafts: true);
      final text = ShareContent.fromDisease(l, draft['rice_blast']!).toText(l);
      expect(text, isNot(contains('ওষুধ')));
    });

    Future<(FakeSharer, FakeCardRenderer)> open(WidgetTester tester, {Uint8List? png}) async {
      final sharer = FakeSharer();
      final renderer = FakeCardRenderer(png);
      final store = InMemoryHistoryStore()..rows['r1'] = rec('rice_blast');
      await pumpApp(tester, saved: doneProfile, overrides: [
        historyDaoProvider.overrideWithValue(store),
        kbProvider.overrideWith(() => _Kb(kb)),
        ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
        sharerProvider.overrideWithValue(sharer),
        analyticsProvider.overrideWithValue(shareAnalytics),
        cardRendererProvider.overrideWithValue(renderer),
      ]);
      tester.view.physicalSize = const Size(1080, 9000);
      unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/result/r1'));
      await tester.pumpAndSettle();
      return (sharer, renderer);
    }

    testWidgets('shares the card image together with the text', (tester) async {
      final (sharer, renderer) = await open(tester, png: Uint8List.fromList([1, 2, 3]));
      await tester.tap(find.byKey(const Key('share_button')));
      await tester.pumpAndSettle();
      expect(renderer.renders, 1);
      expect(sharer.shared.single.png, [1, 2, 3]);
      expect(sharer.shared.single.text, contains('ধানের ব্লাস্ট রোগ'));
      expect(shareAnalytics.names, contains('share_tapped'));
    });

    testWidgets('if the card cannot be drawn the text is still shared', (tester) async {
      final (sharer, _) = await open(tester, png: null);
      await tester.tap(find.byKey(const Key('share_button')));
      await tester.pumpAndSettle();
      expect(sharer.shared.single.png, isNull);
      expect(sharer.shared.single.text, isNotEmpty);
    });

    testWidgets('a share-sheet failure shows a message instead of crashing', (tester) async {
      final (sharer, _) = await open(tester, png: null);
      sharer.throws = Exception('no activity');
      await tester.tap(find.byKey(const Key('share_button')));
      await tester.pumpAndSettle();
      expect(find.text('শেয়ার করা যায়নি।'), findsOneWidget);
    });
  });
}
