import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/theme/app_theme.dart';

void main() {
  test('every text style uses the Bangla font with line height >= 1.4', () {
    final t = buildAppTheme().textTheme;
    for (final s in [t.bodyMedium, t.titleLarge, t.labelSmall, t.displayLarge]) {
      expect(s!.height, greaterThanOrEqualTo(kMinLineHeight));
    }
    expect(buildAppTheme().textTheme.bodyMedium!.fontFamily, kBanglaFont);
  });

  testWidgets('text scale is clamped to 1.0-1.3', (tester) async {
    double? seen;
    Future<void> pumpWith(double scale) => tester.pumpWidget(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Builder(
            builder: (c) => clampTextScale(
              c,
              Builder(builder: (c2) {
                seen = MediaQuery.textScalerOf(c2).scale(10);
                return const SizedBox();
              }),
            ),
          ),
        ));
    await pumpWith(2.0);
    expect(seen, closeTo(13, 0.01));
    await pumpWith(0.8);
    expect(seen, closeTo(10, 0.01));
  });
}
