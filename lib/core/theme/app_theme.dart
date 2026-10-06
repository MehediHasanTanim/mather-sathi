import 'package:flutter/material.dart';

const kBanglaFont = 'NotoSansBengali';
const kMinLineHeight = 1.4;
const kMinTextScale = 1.0;
const kMaxTextScale = 1.3;

/// Ensures every style has at least [kMinLineHeight] so Bangla vowel marks are not clipped.
TextTheme withMinLineHeight(TextTheme t) {
  TextStyle? fix(TextStyle? s) {
    if (s == null) return null;
    final h = s.height ?? kMinLineHeight;
    return s.copyWith(height: h < kMinLineHeight ? kMinLineHeight : h);
  }

  return t.copyWith(
    displayLarge: fix(t.displayLarge), displayMedium: fix(t.displayMedium),
    displaySmall: fix(t.displaySmall), headlineLarge: fix(t.headlineLarge),
    headlineMedium: fix(t.headlineMedium), headlineSmall: fix(t.headlineSmall),
    titleLarge: fix(t.titleLarge), titleMedium: fix(t.titleMedium),
    titleSmall: fix(t.titleSmall), bodyLarge: fix(t.bodyLarge),
    bodyMedium: fix(t.bodyMedium), bodySmall: fix(t.bodySmall),
    labelLarge: fix(t.labelLarge), labelMedium: fix(t.labelMedium),
    labelSmall: fix(t.labelSmall),
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF2E7D32),
    fontFamily: kBanglaFont,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  return base.copyWith(
    textTheme: withMinLineHeight(base.textTheme),
    primaryTextTheme: withMinLineHeight(base.primaryTextTheme),
    visualDensity: VisualDensity.standard,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}

/// Clamps the system font scale so large fonts do not break layouts.
Widget clampTextScale(BuildContext context, Widget? child) =>
    MediaQuery.withClampedTextScaling(
      minScaleFactor: kMinTextScale,
      maxScaleFactor: kMaxTextScale,
      child: child ?? const SizedBox.shrink(),
    );
