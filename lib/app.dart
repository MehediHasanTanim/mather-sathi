import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'core/l10n/gen/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/sync/sync_providers.dart';

class KrishiApp extends ConsumerWidget {
  const KrishiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Back online: push whatever is waiting (history, reports).
    ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      if (next.value == true && prev?.value != true) unawaited(ref.read(syncServiceProvider).flush());
    });
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('bn', 'BD'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: clampTextScale,
    );
  }
}
