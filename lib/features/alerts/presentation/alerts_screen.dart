import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.alertsTitle)),
      body: Center(child: Text(l.comingSoon)),
    );
  }
}
