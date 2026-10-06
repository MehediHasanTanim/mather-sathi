import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/core/l10n/bn_numerals.dart';
import 'package:mather_sathi/features/geo/presentation/search_picker.dart';

import '../support/fakes.dart';

ProviderContainer container(FakeRemoteConfig rc) {
  final c = ProviderContainer(
      overrides: [remoteConfigSourceProvider.overrideWithValue(rc)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('RemoteFlags', () {
    test('uses baked-in defaults when Remote Config is unreachable', () async {
      final c = container(FakeRemoteConfig(fails: true));
      await c.read(remoteFlagsProvider.notifier).refresh(); // must not throw
      expect(c.read(remoteFlagsProvider), RemoteFlags.defaults);
    });

    test('applies fetched values and ignores malformed ones', () async {
      final c = container(FakeRemoteConfig(values: {
        'conf_high': '0.9',
        'blur_threshold': 'abc',
        'cloud_diagnosis_enabled': 'false',
        'helpline_number': '16123',
      }));
      await c.read(remoteFlagsProvider.notifier).refresh();
      final f = c.read(remoteFlagsProvider);
      expect(f.confHigh, 0.9);
      expect(f.blurThreshold, RemoteFlags.defaults.blurThreshold);
      expect(f.cloudDiagnosisEnabled, isFalse);
    });

    test('dev overrides win over fetched values', () async {
      final c = ProviderContainer(overrides: [
        remoteConfigSourceProvider
            .overrideWithValue(FakeRemoteConfig(values: {'conf_high': '0.9'})),
        remoteFlagOverridesProvider.overrideWithValue({'conf_high': 0.5}),
      ]);
      addTearDown(c.dispose);
      await c.read(remoteFlagsProvider.notifier).refresh();
      expect(c.read(remoteFlagsProvider).confHigh, 0.5);
    });
  });

  group('Bangla numerals', () {
    test('toBnDigits', () => expect(toBnDigits('Tk 1,250'), 'Tk ১,২৫০'));
    test('formatBnNumber uses Bangla digits',
        () => expect(formatBnNumber(2026), matches(RegExp(r'^[০-৯,]+$'))));
  });

  group('picker filter', () {
    const items = [
      PickerItem(value: 1, labelBn: 'ঢাকা', labelEn: 'Dhaka'),
      PickerItem(value: 2, labelBn: 'ময়মনসিংহ', labelEn: 'Mymensingh'),
    ];
    test('matches Bangla and English, empty query returns all', () {
      expect(filterPickerItems(items, 'ময়').single.value, 2);
      expect(filterPickerItems(items, 'dha').single.value, 1);
      expect(filterPickerItems(items, '  ').length, 2);
      expect(filterPickerItems(items, 'zzz'), isEmpty);
    });
  });
}
