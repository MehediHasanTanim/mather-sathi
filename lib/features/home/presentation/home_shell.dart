import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.photo_camera), label: l.tabScan),
          NavigationDestination(icon: const Icon(Icons.history), label: l.tabHistory),
          NavigationDestination(icon: const Icon(Icons.notifications), label: l.tabAlerts),
          NavigationDestination(icon: const Icon(Icons.settings), label: l.tabSettings),
        ],
      ),
    );
  }
}
