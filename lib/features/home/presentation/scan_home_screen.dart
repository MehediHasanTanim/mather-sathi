import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';

/// Placeholder; the crop grid and capture flow arrive in Phase 2.
class ScanHomeScreen extends StatelessWidget {
  const ScanHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.appName)),
      body: Center(child: Text(l.homeTitle, style: Theme.of(context).textTheme.titleLarge)),
    );
  }
}
