import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/bn_numerals.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../diagnosis/domain/diagnosis_models.dart';
import '../../kb/domain/kb_models.dart';
import '../../kb/kb_provider.dart';
import '../../result/presentation/result_screen.dart';
import '../domain/diagnosis_record.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final history = ref.watch(historyProvider);
    final kb = ref.watch(kbProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l.historyTitle)),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l.loadError)),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(l.historyEmpty, key: const Key('history_empty')),
                ]),
              )
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _HistoryTile(record: rows[i], kb: kb),
              ),
      ),
    );
  }
}

/// Title shown for a row: the saved name snapshot, or a state label for non-diagnoses.
String historyTitle(AppLocalizations l, DiagnosisRecord r, KnowledgeBase? kb) => switch (r.diseaseId) {
      kGeneralAdviceId => l.generalAdviceTitle,
      kHealthy => l.historyHealthy,
      null || kUnknown => l.historyUnknown,
      final id => r.diseaseNameBn ?? (kb == null ? null : kb[id]?.nameBn) ?? '',
    };

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.kb});
  final DiagnosisRecord record;
  final KnowledgeBase? kb;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final disease = record.diseaseId == null ? null : kb?[record.diseaseId!];
    return ListTile(
      key: Key('history_${record.id}'),
      minVerticalPadding: 12,
      leading: _Thumb(path: record.photoPath),
      title: Text(historyTitle(l, record, kb), maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${cropDisplayName(l, record)} • ${formatBnDate(record.diagnosedAt.toLocal())}'),
      trailing: disease == null ? null : _UrgencyBadge(urgency: disease.urgency),
      onTap: () => context.push(resultRoute(record.id)),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final fallback = Container(
      width: size, height: size, color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.eco),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: path == null
          ? fallback
          : Image.file(File(path!), width: size, height: size, fit: BoxFit.cover, cacheWidth: 160, errorBuilder: (_, _, _) => fallback),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.urgency});
  final Urgency urgency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Colour is never the only signal: every badge has an icon and a word.
    final (color, icon, text) = switch (urgency) {
      Urgency.high => (Colors.red.shade700, Icons.error, l.badgeUrgent),
      Urgency.medium => (Colors.orange.shade900, Icons.warning_amber_rounded, l.badgeWatch),
      Urgency.low => (Colors.green.shade800, Icons.check_circle, l.badgePrevent),
    };
    return Chip(
      key: const Key('urgency_badge'),
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
