import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../domain/weather_info.dart';
import '../providers/weather_provider.dart';

/// Home-screen warning for the primary crop. Dismissable; stays dismissed until a newer forecast arrives.
class WeatherBannerView extends ConsumerWidget {
  const WeatherBannerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = ref.watch(weatherBannerProvider);
    if (banner == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final high = banner.risk.level == RiskLevel.high;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('weather_banner'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: high ? scheme.errorContainer : scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(
              high ? Icons.warning_amber_rounded : Icons.cloud,
              color: high ? scheme.error : scheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '⛅ ${banner.risk.messageBn}',
                key: const Key('weather_message'),
              ),
            ),
            IconButton(
              key: const Key('weather_dismiss'),
              tooltip: l.weatherDismiss,
              icon: const Icon(Icons.close),
              onPressed: () => ref
                  .read(weatherDismissedProvider.notifier)
                  .dismiss(banner.fetchedAt),
            ),
          ],
        ),
      ),
    );
  }
}
