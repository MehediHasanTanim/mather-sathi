import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/flags/remote_flags.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../settings/providers/app_info.dart';

/// True when [current] ("1.2.3" or "1.2.3+4") is older than [minimum]. Only the dotted numbers are compared; a
/// malformed or empty [minimum] means no update is required, and so does a malformed [current] (never nag on a guess).
bool isOlderVersion(String current, String minimum) {
  List<int>? parse(String v) {
    final core = v.split('+').first.trim();
    if (!RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(core)) return null;
    return core.split('.').map(int.parse).toList();
  }

  final c = parse(current), m = parse(minimum);
  if (c == null || m == null) return false;
  for (var i = 0; i < 4; i++) {
    final a = i < c.length ? c[i] : 0, b = i < m.length ? m[i] : 0;
    if (a != b) return a < b;
  }
  return false;
}

/// Opens the store page; faked in tests.
abstract interface class StoreOpener {
  Future<bool> open();
}

class PlayStoreOpener implements StoreOpener {
  @override
  Future<bool> open() async {
    try {
      final id = (await PackageInfo.fromPlatform()).packageName;
      return await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=$id'), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final storeOpenerProvider = Provider<StoreOpener>((ref) => PlayStoreOpener());

/// Soft-force update (Design §16.1 `min_app_version`): a banner on the home screen, never a block, so a farmer on a slow
/// connection can still use the app. Hidden while the installed version is unknown.
final updateNeededProvider = Provider<bool>((ref) {
  final min = ref.watch(remoteFlagsProvider.select((f) => f.minAppVersion));
  final current = ref.watch(appVersionProvider).value;
  return current != null && isOlderVersion(current, min);
});

class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(updateNeededProvider)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Card(
      key: const Key('update_banner'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          const Icon(Icons.system_update),
          const SizedBox(width: 12),
          Expanded(child: Text(l.updateAvailable)),
          TextButton(key: const Key('update_action'), onPressed: () => ref.read(storeOpenerProvider).open(), child: Text(l.updateAction)),
        ]),
      ),
    );
  }
}
