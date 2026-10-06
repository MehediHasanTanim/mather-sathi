import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../capture/presentation/preview_screen.dart' show issueTip;
import '../../capture/providers/capture_provider.dart';
import '../../crops/crop.dart';
import '../../kb/domain/kb_models.dart';
import '../../kb/kb_provider.dart';
import '../domain/diagnosis_models.dart';
import '../providers/diagnosis_providers.dart';

const kDiagnosisRoute = '/diagnosis';

String failureMessage(AppLocalizations l, DiagnosisFailure f) => switch (f) {
      NeedsInternet() => l.needsInternet,
      OfflineModelMissing() => l.offlineModelMissing,
      DailyCapReached() => l.dailyCapReached,
      CloudTimeout() || ServiceRejected() || ServerError() => l.diagnosisFailed,
    };

/// Temporary result view for milestone M1: shows what the KB says for the returned `disease_id`.
/// Phase 4 replaces it with the full result screen (sections, TTS, feedback, history).
class DiagnosisResultScreen extends ConsumerWidget {
  const DiagnosisResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final flow = ref.watch(diagnosisFlowProvider);
    final kb = ref.watch(kbProvider).value;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(diagnosisFlowProvider.notifier).reset();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.resultTitle)),
        body: SafeArea(
          child: switch (flow) {
            FlowIdle() || FlowRunning() => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l.analyzing),
                ]),
              ),
            FlowFailed(:final failure) => _Message(text: failureMessage(l, failure)),
            FlowDone(:final outcome) => switch (outcome) {
                NeedsRetake(:final issue) => _Message(
                    text: issueTip(l, issue, _cropLabel(l, ref)),
                  ),
                GeneralAdvice() => _General(advice: outcome),
                Classified() => _Classified(result: outcome.result, kb: kb),
              },
          },
        ),
      ),
    );
  }

  String _cropLabel(AppLocalizations l, WidgetRef ref) {
    final s = ref.read(captureProvider).selection;
    return s == null ? '' : (s.isOther ? s.label! : cropName(l, s.id));
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.info_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(text,
                key: const Key('result_message'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(AppLocalizations.of(context).back)),
          ]),
        ),
      );
}

String confidenceText(AppLocalizations l, Confidence c) => switch (c) {
      Confidence.high => l.confHigh,
      Confidence.medium => l.confMedium,
      Confidence.low => l.confLow,
    };

class _Classified extends StatelessWidget {
  const _Classified({required this.result, required this.kb});
  final DiagnosisResult result;
  final KnowledgeBase? kb;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final disease = kb?[result.diseaseId];

    if (result.diseaseId == kHealthy) return _Message(text: l.resultHealthy);
    if (disease == null) return _Message(text: '${l.resultUnknown}\n${l.resultUnknownHint}');

    final color = switch (disease.urgency) {
      Urgency.high => Colors.red.shade700,
      Urgency.medium => Colors.orange.shade800,
      Urgency.low => Colors.green.shade700,
    };
    Widget section(String title, List<String> lines) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            for (final s in lines) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $s')),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (kb?.includesDrafts == true || !disease.published)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(l.draftKbBanner, key: const Key('draft_banner'))),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(disease.nameBn,
                key: const Key('disease_name'),
                style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(confidenceText(l, result.confidence), style: t.bodyMedium?.copyWith(color: Colors.white)),
            if (disease.urgency == Urgency.high)
              Text('⚠️ ${l.urgentTreatment}', style: t.bodyMedium?.copyWith(color: Colors.white)),
          ]),
        ),
        section(l.sectionDescription, [disease.descriptionBn]),
        section(l.sectionSymptoms, disease.symptomsBn),
        section(l.sectionPrevention, disease.preventionBn),
        if (disease.seeExpert || result.confidence != Confidence.high)
          Padding(padding: const EdgeInsets.only(top: 16), child: Text('👨‍⚕️ ${l.seeExpert}', style: t.titleMedium)),
        const SizedBox(height: 16),
        Text('ℹ️ ${l.aiDisclaimer}', style: t.bodySmall),
      ],
    );
  }
}

class _General extends StatelessWidget {
  const _General({required this.advice});
  final GeneralAdvice advice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(advice.summaryBn, key: const Key('general_summary'), style: Theme.of(context).textTheme.titleMedium),
        for (final s in advice.preventionBn) Padding(padding: const EdgeInsets.only(top: 8), child: Text('• $s')),
        const SizedBox(height: 16),
        Text('👨‍⚕️ ${l.seeExpert}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Text('ℹ️ ${l.aiDisclaimer}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
