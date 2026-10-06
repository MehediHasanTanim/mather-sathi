import 'package:flutter/material.dart';

/// Placeholder theme; the bundled Bangla font and text scaling arrive in Phase 1 (task 1.2).
ThemeData buildAppTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF2E7D32),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
