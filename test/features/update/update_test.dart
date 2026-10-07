import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/core/l10n/gen/app_localizations_bn.dart';
import 'package:mather_sathi/features/diagnosis/domain/diagnosis_models.dart';
import 'package:mather_sathi/features/diagnosis/presentation/analyzing_screen.dart' show failureMessage;
import 'package:mather_sathi/features/settings/providers/app_info.dart';
import 'package:mather_sathi/features/update/app_update.dart';

import '../../support/pump_app.dart';

class _Opener implements StoreOpener {
  int opened = 0;
  @override
  Future<bool> open() async => ++opened > 0;
}

void main() {
  group('isOlderVersion', () {
    test('compares dotted numbers, ignoring the build suffix', () {
      expect(isOlderVersion('1.2.3+4', '1.2.4'), isTrue);
      expect(isOlderVersion('1.2.3', '1.2.3'), isFalse);
      expect(isOlderVersion('1.10.0', '1.9.9'), isFalse, reason: 'numeric, not alphabetical');
      expect(isOlderVersion('1.9', '1.9.1'), isTrue);
      expect(isOlderVersion('2.0.0+1', '1.99.99'), isFalse);
    });
    test('an empty or malformed minimum, or an unreadable current version, never nags', () {
      for (final bad in ['', 'abc', '1..2', '1.2.x', 'v1.2']) {
        expect(isOlderVersion('1.0.0', bad), isFalse, reason: bad);
        expect(isOlderVersion(bad, '9.9.9'), isFalse, reason: bad);
      }
    });
  });

  group('update banner on the home screen', () {
    Future<_Opener> open(WidgetTester t, {required String installed, String minimum = ''}) async {
      final opener = _Opener();
      await pumpApp(t, saved: doneProfile, overrides: [
        appVersionProvider.overrideWith((_) async => installed),
        remoteFlagOverridesProvider.overrideWithValue({'min_app_version': minimum}),
        storeOpenerProvider.overrideWithValue(opener),
      ]);
      return opener;
    }

    testWidgets('shown when the installed version is below min_app_version, and opens the store', (t) async {
      final opener = await open(t, installed: '0.1.0+1', minimum: '0.2.0');
      expect(find.byKey(const Key('update_banner')), findsOneWidget);
      await t.tap(find.byKey(const Key('update_action')));
      await t.pump();
      expect(opener.opened, 1);
    });
    testWidgets('hidden at or above the minimum, and when no minimum is set', (t) async {
      await open(t, installed: '0.2.0+1', minimum: '0.2.0');
      expect(find.byKey(const Key('update_banner')), findsNothing);
    });
    testWidgets('hidden with no minimum configured', (t) async {
      await open(t, installed: '0.1.0+1');
      expect(find.byKey(const Key('update_banner')), findsNothing);
    });
  });

  group('daily cap message (daily_cap_display)', () {
    final l = AppLocalizationsBn();
    test('uses the Remote Config text when set, the built-in Bangla text otherwise', () {
      expect(failureMessage(l, const DailyCapReached(), capText: 'আজ আর নয়'), 'আজ আর নয়');
      expect(failureMessage(l, const DailyCapReached()), l.dailyCapReached);
      expect(failureMessage(l, const DailyCapReached(), capText: ''), l.dailyCapReached);
    });
    test('the flag is read from daily_cap_display', () {
      expect(RemoteFlags.fromValues({'daily_cap_display': 'x'}).dailyCapDisplay, 'x');
      expect(RemoteFlags.defaults.dailyCapDisplay, '');
    });
  });
}
