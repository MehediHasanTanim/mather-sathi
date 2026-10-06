import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../capture/presentation/preview_screen.dart' show issueTip;
import '../../capture/providers/capture_provider.dart';
import '../../crops/crop.dart';
import '../../result/presentation/result_screen.dart' show resultRoute;
import '../domain/diagnosis_models.dart';
import '../domain/image_issue.dart';
import '../providers/diagnosis_providers.dart';

const kAnalyzingRoute = '/analyzing';

String failureMessage(AppLocalizations l, DiagnosisFailure f) => switch (f) {
      NeedsInternet() => l.needsInternet,
      OfflineModelMissing() => l.offlineModelMissing,
      DailyCapReached() => l.dailyCapReached,
      CloudTimeout() || ServiceRejected() || ServerError() => l.diagnosisFailed,
    };

/// Progress while the diagnosis runs, plus the retake and failure states. On success it hands over to the result screen.
class AnalyzingScreen extends ConsumerWidget {
  const AnalyzingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final flow = ref.watch(diagnosisFlowProvider);
    final notifier = ref.read(diagnosisFlowProvider.notifier);

    void showResult(String historyId) {
      // Home, then the result on top: Back from the result returns home, not to a stale preview.
      ref.read(captureProvider.notifier).reset();
      notifier.reset();
      context.go('/');
      context.push(resultRoute(historyId));
    }

    // Checked on every build (not via a listener) because the flow can already be done when this screen is first built.
    if (flow is FlowDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Re-check: showResult resets the flow, so a duplicate callback finds it idle and does nothing.
        final current = ref.read(diagnosisFlowProvider);
        if (context.mounted && current is FlowDone) showResult(current.historyId);
      });
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && ref.read(diagnosisFlowProvider) is FlowRunning) notifier.cancel();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.resultTitle)),
        body: SafeArea(
          child: switch (flow) {
            FlowIdle() || FlowDone() => const SizedBox.shrink(),
            FlowRunning(:final stage) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(stage == FlowStage.analyzing ? l.analyzing : l.savingResult, key: const Key('analyzing_text')),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    key: const Key('cancel_analysis'),
                    onPressed: () {
                      notifier.cancel();
                      context.pop();
                    },
                    child: Text(l.cancel),
                  ),
                ]),
              ),
            FlowRetake(:final issue) => _Problem(
                icon: Icons.photo_camera,
                text: issueTip(l, issue, _cropLabel(l, ref)),
                actions: [
                  FilledButton(
                    key: const Key('retake_action'),
                    onPressed: () {
                      notifier.reset();
                      context.pop(); // back to the preview, which has the retake buttons
                    },
                    child: Text(l.retake),
                  ),
                  if (issue == ImageIssue.wrongCrop)
                    OutlinedButton(
                      key: const Key('change_crop'),
                      onPressed: () {
                        notifier.reset();
                        ref.read(captureProvider.notifier).reset();
                        context.go('/');
                      },
                      child: Text(l.changeCrop),
                    ),
                ],
              ),
            FlowFailed(:final failure) => _Problem(
                icon: Icons.cloud_off,
                text: failureMessage(l, failure),
                actions: [
                  if (canRetry(failure))
                    FilledButton(key: const Key('retry'), onPressed: notifier.retry, child: Text(l.tryAgain)),
                  OutlinedButton(
                    key: const Key('failure_back'),
                    onPressed: () {
                      notifier.reset();
                      context.pop();
                    },
                    child: Text(l.back),
                  ),
                ],
              ),
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

class _Problem extends StatelessWidget {
  const _Problem({required this.icon, required this.text, required this.actions});
  final IconData icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(text, key: const Key('result_message'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 32),
            for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
          ],
        ),
      );
}
