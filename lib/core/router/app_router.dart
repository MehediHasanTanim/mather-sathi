import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/capture/presentation/preview_screen.dart';
import '../../features/diagnosis/presentation/analyzing_screen.dart';
import '../../features/result/presentation/result_screen.dart';
import '../../features/expert/expert_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/home/presentation/scan_home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Pure redirect rule, kept separate for testing.
/// [onboardingDone] is null while the profile is still loading: do not redirect then.
String? onboardingRedirect({required bool? onboardingDone, required String location}) {
  if (onboardingDone == null) return null;
  final atOnboarding = location == '/onboarding';
  if (!onboardingDone && !atOnboarding) return '/onboarding';
  if (onboardingDone && atOnboarding) return '/';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(profileProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) => onboardingRedirect(
      onboardingDone: ref.read(profileProvider).value?.onboardingDone,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: kExpertRoute, builder: (_, _) => const ExpertScreen()),
      GoRoute(path: kAnalyzingRoute, builder: (_, _) => const AnalyzingScreen()),
      GoRoute(
        path: '/result/:id',
        builder: (_, s) => ResultScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/capture/preview', builder: (_, _) => const PreviewScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const ScanHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
