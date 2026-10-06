import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/anonymous_auth.dart';
import '../../../core/l10n/bn_numerals.dart';
import '../../../core/l10n/gen/app_localizations.dart';

/// Placeholder; real settings arrive in Phase 8. Hosts the Bangla rendering
/// check (task 1.2) and, in debug builds, the anonymous uid (task 0.4 smoke test).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.banglaCheckTitle, style: t.titleMedium),
          const SizedBox(height: 8),
          Text(l.banglaCheckSample, key: const Key('bangla_sample'), style: t.bodyLarge),
          const SizedBox(height: 8),
          Text(l.banglaCheckDigits(formatBnNumber(1234567890)), style: t.bodyLarge),
          Text(toBnDigits('০১২৩৪৫৬৭৮৯ → 0123456789'), style: t.bodyLarge),
          if (kDebugMode) ...[
            const Divider(height: 32),
            Text(ref.watch(anonymousUidProvider).when(
                  data: (v) => 'uid: $v',
                  loading: () => 'signing in…',
                  error: (e, _) => 'sign-in failed: $e',
                )),
          ],
        ],
      ),
    );
  }
}
