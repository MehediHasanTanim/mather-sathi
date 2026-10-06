import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/bn_numerals.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../crops/crop.dart';
import '../../diagnosis/domain/diagnosis_models.dart';
import '../../history/domain/diagnosis_record.dart';
import '../../history/providers/history_provider.dart';
import '../../kb/domain/kb_models.dart';
import '../../kb/kb_provider.dart';
import '../../tts/listen_button.dart';
import '../../tts/tts_script.dart';
import 'feedback_row.dart';

String resultRoute(String id) => '/result/$id';

String confidenceText(AppLocalizations l, Confidence c) => switch (c) {
      Confidence.high => l.confHigh,
      Confidence.medium => l.confMedium,
      Confidence.low => l.confLow,
    };

Confidence confidenceOf(String? v) => Confidence.values.asNameMap()[v] ?? Confidence.low;

/// A saved diagnosis, rendered from its `disease_id` and the CURRENT KB. Every line of treatment text comes from the KB.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entry = ref.watch(historyEntryProvider(id));
    final kb = ref.watch(kbProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l.resultTitle)),
      body: SafeArea(
        child: entry.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Plain(text: l.loadError),
          data: (r) => r == null ? _Plain(text: l.resultNotFound) : _Body(record: r, kb: kb),
        ),
      ),
    );
  }
}

class _Plain extends StatelessWidget {
  const _Plain({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)));
}

class _Body extends ConsumerWidget {
  const _Body({required this.record, required this.kb});
  final DiagnosisRecord record;
  final KnowledgeBase? kb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final conf = confidenceOf(record.confidence);
    final diseaseId = record.diseaseId;

    final List<Widget> content;
    if (diseaseId == kGeneralAdviceId) {
      content = _general(context, l, t);
    } else if (diseaseId == kHealthy) {
      content = _healthy(context, l, t);
    } else if (diseaseId == null || diseaseId == kUnknown) {
      content = _unknown(context, l, t);
    } else {
      final d = kb?[diseaseId];
      content = d == null ? _gone(context, l, t, conf) : _disease(context, l, t, d, conf);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Photo(path: record.photoPath),
        if (record.source == 'on_device') _OfflineNotice(showCaveat: conf == Confidence.low || diseaseId == kUnknown),
        ...content,
        const SizedBox(height: 16),
        FeedbackRow(record: record, kb: kb),
        const SizedBox(height: 16),
        Text('ℹ️ ${l.aiDisclaimer}', key: const Key('ai_disclaimer'), style: t.bodySmall),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---- classified disease ----
  List<Widget> _disease(BuildContext context, AppLocalizations l, TextTheme t, Disease d, Confidence conf) {
    final (color, icon, urgencyText) = switch (d.urgency) {
      Urgency.high => (Colors.red.shade700, Icons.error, l.urgentTreatment),
      Urgency.medium => (Colors.orange.shade900, Icons.warning_amber_rounded, l.urgencyMedium),
      Urgency.low => (Colors.green.shade800, Icons.check_circle, l.urgencyLow),
    };
    final showMedicine = d.published && d.medicine.isNotEmpty;
    final expert = d.seeExpert || conf != Confidence.high;

    Widget section(String title, List<String> lines, {bool bullets = true}) => lines.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium),
              for (final s in lines) Padding(padding: const EdgeInsets.only(top: 4), child: Text(bullets ? '• $s' : s)),
            ]),
          );

    return [
      if (!d.published || kb?.includesDrafts == true)
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(padding: const EdgeInsets.all(12), child: Text(l.draftKbBanner, key: const Key('draft_banner'))),
        ),
      if (_kbChanged) _Note(text: l.kbUpdated, keyName: 'kb_updated'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(d.nameBn,
                  key: const Key('disease_name'),
                  style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(confidenceText(l, conf), key: const Key('confidence_text'), style: t.bodyMedium?.copyWith(color: Colors.white)),
          Text(urgencyText, key: const Key('urgency_text'), style: t.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 12),
      ListenButton(script: () => buildDiseaseScript(l, d)),
      section(l.sectionDescription, [d.descriptionBn], bullets: false),
      section(l.sectionSymptoms, d.symptomsBn),
      if (d.immediateBn.isNotEmpty || showMedicine) ...[
        Padding(padding: const EdgeInsets.only(top: 16), child: Text(l.sectionTreatment, style: t.titleMedium)),
        if (d.immediateBn.isNotEmpty) section(l.immediateLabel, d.immediateBn),
        if (showMedicine) ...[
          for (final m in d.medicine) _MedicineCard(m: m),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('⛑️ ${l.safetyLine}', key: const Key('safety_line'), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ],
      section(l.sectionPrevention, d.preventionBn),
      if (expert) _Expert(),
    ];
  }

  bool get _kbChanged => kb != null && record.kbSeq != null && kb!.seq > record.kbSeq!;

  // ---- KB entry no longer exists ----
  List<Widget> _gone(BuildContext context, AppLocalizations l, TextTheme t, Confidence conf) => [
        Text(record.diseaseNameBn ?? '', key: const Key('disease_name'), style: t.headlineSmall),
        const SizedBox(height: 4),
        Text(l.kbEntryGone, key: const Key('kb_gone')),
        _Expert(),
      ];

  // ---- healthy ----
  List<Widget> _healthy(BuildContext context, AppLocalizations l, TextTheme t) {
    // Prevention tips come from this crop's reviewed KB entries, not from generic text.
    final tips = <String>{
      for (final d in kb?.forCrop(record.cropType) ?? const <Disease>[]) ...d.preventionBn,
    }.take(4).toList();
    return [
      Text(l.resultHealthy, key: const Key('result_healthy'), style: t.titleLarge),
      const SizedBox(height: 8),
      ListenButton(script: () => buildMessageScript(l.resultHealthy, tips)),
      if (tips.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(top: 16), child: Text(l.healthyTipsTitle, style: t.titleMedium)),
        for (final s in tips) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $s')),
      ],
    ];
  }

  // ---- unknown ----
  List<Widget> _unknown(BuildContext context, AppLocalizations l, TextTheme t) => [
        Text(l.resultUnknown, key: const Key('result_unknown'), style: t.titleLarge),
        const SizedBox(height: 8),
        Text(l.resultUnknownHint),
        const SizedBox(height: 8),
        ListenButton(script: () => buildMessageScript(l.resultUnknown, [l.resultUnknownHint])),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(
            key: const Key('unknown_retry'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.tryAgain),
          ),
          _ExpertButton(),
        ]),
      ];

  // ---- other crops: general advice, never medicines ----
  List<Widget> _general(BuildContext context, AppLocalizations l, TextTheme t) {
    var summary = '';
    var prevention = <String>[];
    try {
      final j = jsonDecode(record.adviceJson ?? '{}') as Map<String, dynamic>;
      summary = j['summary_bn'] as String? ?? '';
      prevention = [for (final s in (j['prevention_bn'] as List? ?? const [])) s as String];
    } catch (_) {
      // Unreadable advice is shown as nothing rather than crashing the screen.
    }
    return [
      if (record.cropLabel != null) Text(record.cropLabel!, style: t.titleMedium),
      Text(l.generalAdviceTitle, style: t.titleLarge),
      const SizedBox(height: 8),
      Text(summary, key: const Key('general_summary'), style: t.bodyLarge),
      for (final s in prevention) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $s')),
      const SizedBox(height: 8),
      ListenButton(script: () => buildMessageScript(summary, prevention)),
      _Expert(),
    ];
  }
}

/// Offline results are labelled, and a low-confidence one says how to get a better answer.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.showCaveat});
  final bool showCaveat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Chip(
          key: const Key('offline_chip'),
          avatar: const Icon(Icons.cloud_off, size: 18),
          label: Text(l.offlineMode),
          visualDensity: VisualDensity.compact,
        ),
        if (showCaveat) Text('ℹ️ ${l.offlineCaveat}', key: const Key('offline_caveat')),
      ]),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: Image.file(File(path!), fit: BoxFit.cover, cacheWidth: 600, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.keyName});
  final String text;
  final String keyName;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('ℹ️ $text', key: Key(keyName), style: Theme.of(context).textTheme.bodySmall),
      );
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.m});
  final Medicine m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: v),
          ])),
        );
    return Card(
      key: const Key('medicine_card'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          row(l.medicineLabel, m.nameBn),
          row(l.doseLabel, m.doseBn),
          row(l.intervalLabel, m.intervalBn),
          if (m.preHarvestIntervalDays != null)
            row(l.preHarvestLabel, l.preHarvestDays(formatBnNumber(m.preHarvestIntervalDays!))),
        ]),
      ),
    );
  }
}

class _ExpertButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The helpline screen arrives in Phase 8 (task 8.4).
    return OutlinedButton.icon(
      key: const Key('expert_button'),
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingSoon))),
      icon: const Icon(Icons.call),
      label: Text(l.callExpert),
    );
  }
}

class _Expert extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(children: [
        Expanded(child: Text('👨‍⚕️ ${l.seeExpert}', key: const Key('expert_cta'), style: Theme.of(context).textTheme.titleMedium)),
        _ExpertButton(),
      ]),
    );
  }
}

/// Used by the history list (Phase 5) and by tests.
String cropDisplayName(AppLocalizations l, DiagnosisRecord r) =>
    r.cropType == 'other' ? (r.cropLabel ?? '') : cropName(l, r.cropType);
