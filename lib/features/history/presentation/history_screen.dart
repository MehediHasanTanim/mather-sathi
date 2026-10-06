import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.historyTitle)),
      body: Center(child: Text(l.comingSoon)),
    );
  }
}
