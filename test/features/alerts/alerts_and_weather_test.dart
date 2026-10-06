import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/l10n/gen/app_localizations_bn.dart';
import 'package:mather_sathi/features/alerts/domain/alert.dart';
import 'package:mather_sathi/features/alerts/presentation/alerts_screen.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/kb/kb_provider.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/features/weather/domain/weather_info.dart';

import '../../support/diagnosis_fakes.dart';
import '../../support/phase7_fakes.dart';
import '../../support/pump_app.dart';

final _now = DateTime(2026, 10, 6, 12);
const _upazila = '365'; // Savar, in Dhaka (districts.json)

Alert alert(
  String id, {
  String crop = 'rice',
  String disease = 'rice_blast',
  int count = 3,
  Duration ago = const Duration(days: 2),
  String upazila = _upazila,
}) => Alert(
  id: id,
  district: 'dhaka',
  upazila: upazila,
  crop: crop,
  diseaseId: disease,
  count: count,
  lastReportAt: _now.subtract(ago),
);

class _Kb extends KbNotifier {
  @override
  Future<KnowledgeBase> build() async => testKb();
}

Future<void> openAlerts(
  WidgetTester tester,
  FakeAlertsSource source, {
  UserProfile profile = doneProfile,
}) async {
  await pumpApp(
    tester,
    saved: profile,
    alerts: source,
    overrides: [kbProvider.overrideWith(() => _Kb())],
  );
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('সতর্কতা'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Alert / WeatherInfo parsing', () {
    test('Alert.tryParse accepts a good doc and rejects malformed ones', () {
      final good = {
        'district': 'dhaka',
        'upazila': '1',
        'crop': 'rice',
        'diseaseId': 'rice_blast',
        'count': 3,
        'lastReportAt': _now,
      };
      expect(Alert.tryParse('a', good)!.count, 3);
      for (final k in good.keys) {
        expect(
          Alert.tryParse('a', {...good}..remove(k)),
          isNull,
          reason: 'missing $k',
        );
      }
      expect(Alert.tryParse('a', {...good, 'count': '3'}), isNull);
      expect(
        Alert.tryParse('a', {...good, 'lastReportAt': 'yesterday'}),
        isNull,
      );
    });

    test(
      'WeatherInfo.tryParse maps risks, skips malformed ones, finds the crop',
      () {
        final info = WeatherInfo.tryParse({
          'fetchedAt': _now,
          'risks': [
            {'crop': 'rice', 'level': 'watch', 'message_bn': 'ক্ষেত দেখুন'},
            {'crop': 'potato', 'level': 'high', 'message_bn': 'ঝুঁকি বেশি'},
            {'crop': 'jute', 'level': 'severe', 'message_bn': 'x'},
            {'crop': 'onion', 'level': 'watch', 'message_bn': ''},
            'junk',
          ],
        })!;
        expect(info.risks.map((r) => r.crop), ['rice', 'potato']);
        expect(info.forCrop('potato')!.level, RiskLevel.high);
        expect(info.forCrop('jute'), isNull);
        expect(info.forCrop(null), isNull);
        expect(WeatherInfo.tryParse({'risks': []}), isNull);
      },
    );

    test('agoText: just now, hours and days in Bangla digits', () {
      final l = AppLocalizationsBn();
      expect(
        agoText(l, _now.subtract(const Duration(minutes: 5)), _now),
        'এইমাত্র',
      );
      expect(
        agoText(l, _now.subtract(const Duration(hours: 5)), _now),
        '৫ ঘণ্টা আগে',
      );
      expect(
        agoText(l, _now.subtract(const Duration(days: 2, hours: 3)), _now),
        '২ দিন আগে',
      );
    });
  });

  group('alerts feed (task 7.2)', () {
    testWidgets(
      'shows the farmer\'s district and each alert with crop, disease, upazila, time and reporter count',
      (tester) async {
        final src = FakeAlertsSource(
          StreamController<List<Alert>>()..add([
            alert('a1'),
            alert(
              'a2',
              crop: 'potato',
              disease: 'potato_early_blight',
              count: 7,
              ago: const Duration(days: 5),
            ),
          ]),
        );
        await openAlerts(tester, src);
        expect(src.watched, [
          'dhaka',
        ], reason: 'only the farmer\'s own district is queried');
        expect(find.byKey(const Key('alerts_district')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('alerts_district'))).data,
          'ঢাকা জেলা',
        );
        expect(find.text('🌾 ধান — ধানের ব্লাস্ট রোগ'), findsOneWidget);
        expect(find.text('🥔 আলু — আলুর আর্লি ব্লাইট'), findsOneWidget);
        final subtitles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((t) => (t.subtitle! as Text).data!)
            .toList();
        expect(
          subtitles.any(
            (s) =>
                s.contains('সাভার উপজেলা') &&
                s.contains('জন কৃষক রিপোর্ট করেছেন'),
          ),
          isTrue,
        );
        expect(subtitles.any((s) => s.contains('৭ জন কৃষক')), isTrue);
        expect(
          subtitles.any(
            (s) =>
                s.contains('দিন আগে') ||
                s.contains('ঘণ্টা আগে') ||
                s.contains('এইমাত্র'),
          ),
          isTrue,
        );
      },
    );

    testWidgets('an empty feed has a friendly Bangla state', (tester) async {
      await openAlerts(tester, FakeAlertsSource());
      expect(find.byKey(const Key('alerts_empty')), findsOneWidget);
    });

    testWidgets(
      'an alert for a disease missing from this app\'s KB still lists (crop only)',
      (tester) async {
        await openAlerts(
          tester,
          FakeAlertsSource(
            StreamController<List<Alert>>()
              ..add([alert('a1', disease: 'rice_new')]),
          ),
        );
        expect(find.text('🌾 ধান'), findsOneWidget);
      },
    );

    testWidgets('a new alert arrives live without reopening the tab', (
      tester,
    ) async {
      final c = StreamController<List<Alert>>();
      await pumpApp(
        tester,
        saved: doneProfile,
        alerts: FakeAlertsSource(c),
        overrides: [kbProvider.overrideWith(() => _Kb())],
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('সতর্কতা'),
        ),
      );
      c.add([]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alerts_empty')), findsOneWidget);
      c.add([alert('live')]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alert_live')), findsOneWidget);
    });

    testWidgets(
      'no district in the profile asks the farmer to choose one, and queries nothing',
      (tester) async {
        final src = FakeAlertsSource();
        await openAlerts(
          tester,
          src,
          profile: const UserProfile(onboardingDone: true),
        );
        expect(
          find.text('সতর্কতা দেখতে সেটিংসে আপনার জেলা বেছে নিন'),
          findsOneWidget,
        );
        expect(src.watched, isEmpty);
      },
    );
  });

  group('weather banner (task 7.4)', () {
    WeatherInfo info(
      DateTime at, {
      String crop = 'rice',
      RiskLevel level = RiskLevel.watch,
    }) => WeatherInfo(
      fetchedAt: at,
      risks: [
        WeatherRisk(
          crop: crop,
          level: level,
          messageBn: 'বৃষ্টি ও আর্দ্রতা বেশি। ক্ষেত পর্যবেক্ষণে রাখুন।',
        ),
      ],
    );

    testWidgets('shows the warning for the primary crop only', (tester) async {
      await pumpApp(
        tester,
        saved: doneProfile,
        weather: FakeWeatherSource(
          StreamController<WeatherInfo?>()..add(info(_now)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weather_message')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('weather_message'))).data,
        contains('ক্ষেত পর্যবেক্ষণে রাখুন'),
      );
    });

    testWidgets('a risk for a different crop is not shown', (tester) async {
      await pumpApp(
        tester,
        saved: doneProfile,
        weather: FakeWeatherSource(
          StreamController<WeatherInfo?>()..add(info(_now, crop: 'potato')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weather_banner')), findsNothing);
    });

    testWidgets('no weather data or no risks: no banner', (tester) async {
      await pumpApp(tester, saved: doneProfile);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weather_banner')), findsNothing);
    });

    testWidgets('the banner watches the farmer\'s own district', (
      tester,
    ) async {
      final src = FakeWeatherSource();
      await pumpApp(tester, saved: doneProfile, weather: src);
      await tester.pumpAndSettle();
      expect(src.watched, ['dhaka']);
    });

    testWidgets(
      'dismissal hides it, survives a new forecast with the same timestamp, and returns for newer data',
      (tester) async {
        final c = StreamController<WeatherInfo?>();
        final store = FakeDismissStore();
        await pumpApp(
          tester,
          saved: doneProfile,
          weather: FakeWeatherSource(c),
          dismiss: store,
        );
        c.add(info(_now));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('weather_banner')), findsOneWidget);

        await tester.tap(find.byKey(const Key('weather_dismiss')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('weather_banner')), findsNothing);
        expect(store.value, _now.millisecondsSinceEpoch);

        c.add(info(_now)); // same fetch re-delivered: still dismissed
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('weather_banner')), findsNothing);

        c.add(
          info(_now.add(const Duration(hours: 8))),
        ); // next scheduled refresh
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('weather_banner')), findsOneWidget);
      },
    );

    testWidgets(
      'a dismissal remembered from a previous session is honoured at startup',
      (tester) async {
        final store = FakeDismissStore()..value = _now.millisecondsSinceEpoch;
        await pumpApp(
          tester,
          saved: doneProfile,
          weather: FakeWeatherSource(
            StreamController<WeatherInfo?>()..add(info(_now)),
          ),
          dismiss: store,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('weather_banner')), findsNothing);
      },
    );

    testWidgets('a high risk is shown with a warning icon', (tester) async {
      await pumpApp(
        tester,
        saved: doneProfile,
        weather: FakeWeatherSource(
          StreamController<WeatherInfo?>()
            ..add(info(_now, level: RiskLevel.high)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
