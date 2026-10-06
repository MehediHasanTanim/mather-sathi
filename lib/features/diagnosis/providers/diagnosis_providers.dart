
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_reporter.dart';
import '../../../core/flags/remote_flags.dart';
import '../../capture/domain/crop_selection.dart';
import '../../history/providers/history_provider.dart';
import '../../offline/model_assets.dart';
import '../../sync/sync_providers.dart';
import '../../kb/kb_provider.dart';
import '../data/cloud_client.dart';
import '../diagnosis_service.dart';
import '../domain/diagnosis_models.dart';
import '../domain/image_issue.dart';

class PlusConnectivityChecker implements ConnectivityChecker {
  @override
  Future<bool> isOnline() async =>
      !(await Connectivity().checkConnectivity()).every((r) => r == ConnectivityResult.none);
}

class FirebaseAuthGate implements AuthGate {
  @override
  Future<String> ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
    return user.uid;
  }
}

final connectivityCheckerProvider = Provider<ConnectivityChecker>((ref) => PlusConnectivityChecker());
final authGateProvider = Provider<AuthGate>((ref) => FirebaseAuthGate());
final cloudClientProvider = Provider<CloudDiagnosisClient>((ref) => CloudDiagnosisClient(firebaseCallable()));

final diagnosisServiceProvider = Provider<DiagnosisService>((ref) => DiagnosisService(
      cloud: ref.watch(cloudClientProvider),
      local: ref.watch(localClassifierProvider),
      connectivity: ref.watch(connectivityCheckerProvider),
      auth: ref.watch(authGateProvider),
      kb: () => ref.read(kbProvider).requireValue,
      flags: () => ref.read(remoteFlagsProvider),
      reporter: ref.watch(errorReporterProvider),
    ));

enum FlowStage { analyzing, saving }

/// State machine for one diagnosis (Design §8.2).
sealed class DiagnosisFlow {
  const DiagnosisFlow();
}

class FlowIdle extends DiagnosisFlow {
  const FlowIdle();
}

class FlowRunning extends DiagnosisFlow {
  const FlowRunning(this.stage);
  final FlowStage stage;
}

class FlowDone extends DiagnosisFlow {
  const FlowDone(this.historyId);
  final String historyId;
}

class FlowRetake extends DiagnosisFlow {
  const FlowRetake(this.issue);
  final ImageIssue issue;
}

class FlowFailed extends DiagnosisFlow {
  const FlowFailed(this.failure);
  final DiagnosisFailure failure;
}

/// Retrying cannot help when the daily cap is spent or the service rejected the app.
bool canRetry(DiagnosisFailure f) => f is! DailyCapReached && f is! ServiceRejected;

final diagnosisFlowProvider =
    NotifierProvider<DiagnosisFlowNotifier, DiagnosisFlow>(DiagnosisFlowNotifier.new);

class DiagnosisFlowNotifier extends Notifier<DiagnosisFlow> {
  int _run = 0;
  Uint8List? _lastJpeg;
  CropSelection? _lastCrop;

  @override
  DiagnosisFlow build() => const FlowIdle();

  /// Runs the diagnosis and saves it to history. A second call while running is ignored.
  Future<void> submit(Uint8List preparedJpeg, CropSelection crop) async {
    if (state is FlowRunning) return;
    _lastJpeg = preparedJpeg;
    _lastCrop = crop;
    final run = ++_run;
    bool stale() => run != _run; // cancelled or superseded

    state = const FlowRunning(FlowStage.analyzing);
    try {
      final outcome = await ref.read(diagnosisServiceProvider).run(preparedJpeg, crop);
      if (stale()) return;
      switch (outcome) {
        case NeedsRetake(:final issue):
          state = FlowRetake(issue);
        case Classified() || GeneralAdvice():
          state = const FlowRunning(FlowStage.saving);
          final id = await ref.read(historyProvider.notifier).saveOutcome(outcome, crop);
          requestSync(ref); // history backup and regional report; never waited on
          if (!stale()) state = FlowDone(id);
      }
    } on DiagnosisFailure catch (f) {
      if (!stale()) state = FlowFailed(f);
    } catch (e, st) {
      debugPrint('diagnosis crashed: $e\n$st');
      if (!stale()) state = const FlowFailed(ServerError('unexpected'));
    }
  }

  Future<void> retry() async {
    final jpeg = _lastJpeg, crop = _lastCrop;
    if (jpeg == null || crop == null) return;
    state = const FlowIdle();
    await submit(jpeg, crop);
  }

  /// Safe at any time: the in-flight result is discarded and nothing is saved.
  void cancel() {
    _run++;
    state = const FlowIdle();
  }

  void reset() => state = const FlowIdle();
}
