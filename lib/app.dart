import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/anonymous_auth.dart';
import 'core/theme/app_theme.dart';

class KrishiApp extends StatelessWidget {
  const KrishiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'কৃষি সহায়',
      theme: buildAppTheme(),
      home: const _SmokeHome(),
    );
  }
}

/// Temporary home: shows the anonymous uid so task 0.4 can be verified on a device.
/// Replaced by the real shell in Phase 1.
class _SmokeHome extends ConsumerWidget {
  const _SmokeHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(anonymousUidProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('কৃষি সহায়', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 12),
            Text(uid.when(
              data: (v) => 'uid: $v',
              loading: () => 'signing in…',
              error: (e, _) => 'sign-in failed: $e',
            )),
          ],
        ),
      ),
    );
  }
}
