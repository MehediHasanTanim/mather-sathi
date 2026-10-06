
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/flags/remote_flags.dart';
import '../../capture/domain/crop_selection.dart';
import '../../kb/kb_provider.dart';
import '../data/cloud_client.dart';
import '../diagnosis_service.dart';
import '../domain/diagnosis_models.dart';

class PlusConnectivityChecker implements ConnectivityChecker {
  @override
  Future<bool> isOnline() async =>
      !(await Connectivity().checkConnectivity()).every((r) => r == ConnectivityResult.none);
}

class FirebaseAuthGate implements AuthGate {
  @override
  Future<void> ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
  }
}

final connectivityCheckerProvider = Provider<ConnectivityChecker>((ref) => PlusConnectivityChecker());
final authGateProvider = Provider<AuthGate>((ref) => FirebaseAuthGate());
final cloudClientProvider = Provider<CloudDiagnosisClient>((ref) => CloudDiagnosisClient(firebaseCallable()));
final localClassifierProvider = Provider<LocalClassifier>((ref) => const NoLocalClassifier());

final diagnosisServiceProvider = Provider<DiagnosisService>((ref) => DiagnosisService(
      cloud: ref.watch(cloudClientProvider),
      local: ref.watch(localClassifierProvider),
      connectivity: ref.watch(connectivityCheckerProvider),
      auth: ref.watch(authGateProvider),
      kb: () => ref.read(kbProvider).requireValue,
      flags: () => ref.read(remoteFlagsProvider),
    ));

sealed class DiagnosisFlow {
  const DiagnosisFlow();
}

class FlowIdle extends DiagnosisFlow {
  const FlowIdle();
}

class FlowRunning extends DiagnosisFlow {
  const FlowRunning();
}

/// Phase 4 replaces [outcome] with a saved history id once history persistence exists.
class FlowDone extends DiagnosisFlow {
  const FlowDone(this.outcome);
  final DiagnosisOutcome outcome;
}

class FlowFailed extends DiagnosisFlow {
  const FlowFailed(this.failure);
  final DiagnosisFailure failure;
}

final diagnosisFlowProvider =
    NotifierProvider<DiagnosisFlowNotifier, DiagnosisFlow>(DiagnosisFlowNotifier.new);

class DiagnosisFlowNotifier extends Notifier<DiagnosisFlow> {
  @override
  DiagnosisFlow build() => const FlowIdle();

  Future<void> submit(Uint8List preparedJpeg, CropSelection crop) async {
    if (state is FlowRunning) return; // ignore double taps
    state = const FlowRunning();
    try {
      state = FlowDone(await ref.read(diagnosisServiceProvider).run(preparedJpeg, crop));
    } on DiagnosisFailure catch (f) {
      state = FlowFailed(f);
    } catch (e, st) {
      debugPrint('diagnosis crashed: $e\n$st');
      state = const FlowFailed(ServerError('unexpected'));
    }
  }

  void reset() => state = const FlowIdle();
}
