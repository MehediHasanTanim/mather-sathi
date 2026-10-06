import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/bn_numerals.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../crops/crop.dart';
import '../../geo/data/districts_repository.dart';
import '../../geo/domain/district.dart';
import '../../kb/kb_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../domain/alert.dart';
import '../providers/alerts_provider.dart';

/// Relative time in Bangla: এইমাত্র / ৫ ঘণ্টা আগে / ২ দিন আগে.
String agoText(AppLocalizations l, DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.inMinutes < 60) return l.agoJustNow;
  if (diff.inHours < 24) return l.agoHours(formatBnNumber(diff.inHours));
  return l.agoDays(formatBnNumber(diff.inDays));
}

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key, this.now});

  /// Injectable clock for tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final slug = ref.watch(profileProvider.select((p) => p.value?.district));
    final districts = ref.watch(districtsProvider).value;
    final District? district = districts
        ?.where((d) => d.slug == slug)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l.alertsTitle)),
      body: slug == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.alertsNoDistrict, textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                if (district != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.alertsDistrict(district.nameBn),
                        key: const Key('alerts_district'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                Expanded(
                  child: ref
                      .watch(alertsProvider(slug))
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Center(child: Text(l.loadError)),
                        data: (alerts) => alerts.isEmpty
                            ? Center(
                                child: Text(
                                  l.alertsEmpty,
                                  key: const Key('alerts_empty'),
                                ),
                              )
                            : ListView.separated(
                                itemCount: alerts.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) => _AlertTile(
                                  alert: alerts[i],
                                  district: district,
                                  now: (now ?? DateTime.now)(),
                                ),
                              ),
                      ),
                ),
              ],
            ),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({
    required this.alert,
    required this.district,
    required this.now,
  });
  final Alert alert;
  final District? district;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final disease = ref.watch(kbProvider).value?[alert.diseaseId];
    final upazila = district?.upazilaById(alert.upazila);
    final title =
        '${cropEmoji(alert.crop)} ${cropName(l, alert.crop)}${disease == null ? '' : ' — ${disease.nameBn}'}';
    return ListTile(
      key: Key('alert_${alert.id}'),
      minVerticalPadding: 12,
      title: Text(title),
      subtitle: Text(
        [
          if (upazila != null) l.alertUpazila(upazila.nameBn),
          agoText(l, alert.lastReportAt, now),
          l.alertReporters(formatBnNumber(alert.count)),
        ].join(' • '),
      ),
    );
  }
}
