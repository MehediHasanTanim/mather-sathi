import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flags/remote_flags.dart';
import '../../core/l10n/bn_numerals.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../history/providers/history_provider.dart' show clockProvider;
import 'expert_providers.dart';
import 'helpline_schedule.dart';
import '../../core/analytics/analytics.dart';

const kExpertRoute = '/expert';

/// The agriculture helpline (Feature 5). Number, hours and charge come from Remote Config because the public figures
/// are unverified and can change; nothing about the helpline is hard-coded here.
class ExpertScreen extends ConsumerWidget {
  const ExpertScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final flags = ref.watch(remoteFlagsProvider);
    final schedule = HelplineSchedule.parse(flags.helplineSchedule);
    final open = schedule?.isOpenAt(ref.watch(clockProvider)());

    return Scaffold(
      appBar: AppBar(title: Text(l.expertTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📞 ${l.seeExpert}', style: t.titleMedium),
                const SizedBox(height: 8),
                Text(toBnDigits(flags.helplineNumber), key: const Key('helpline_number'), style: t.headlineMedium),
                if (open != null) ...[
                  const SizedBox(height: 8),
                  Chip(
                    key: Key(open ? 'helpline_open' : 'helpline_closed'),
                    avatar: Icon(open ? Icons.check_circle : Icons.schedule, size: 18, color: open ? Colors.green.shade800 : Colors.red.shade800),
                    label: Text(open ? l.expertOpenNow : l.expertClosedNow),
                  ),
                ],
                if (flags.helplineHoursText.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.expertHours(flags.helplineHoursText), key: const Key('helpline_hours'))),
                if (flags.helplineNote.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(flags.helplineNote, key: const Key('helpline_note'))),
                const SizedBox(height: 16),
                // Never disabled when closed: the hours text may be stale, and a call to a closed line is harmless.
                FilledButton.icon(
                  key: const Key('helpline_call'),
                  onPressed: () async {
                    Ev.expertCallTapped(ref.read(analyticsProvider));
                    final ok = await ref.read(dialerProvider).dial(flags.helplineNumber);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.expertCallFailed(flags.helplineNumber))));
                    }
                  },
                  icon: const Icon(Icons.call),
                  label: Text(l.expertCallNow),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text('ℹ️ ${l.aiDisclaimer}', style: t.bodySmall),
        ],
      ),
    );
  }
}
