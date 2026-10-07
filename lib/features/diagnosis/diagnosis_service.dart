import 'dart:async';
import 'dart:typed_data';

import '../../core/analytics/analytics.dart';
import '../../core/errors/error_reporter.dart';
import '../../core/flags/remote_flags.dart';
import '../capture/domain/crop_selection.dart';
import '../kb/domain/kb_models.dart';
import 'data/cloud_client.dart';
import 'domain/diagnosis_models.dart';
import 'domain/image_issue.dart';

abstract interface class ConnectivityChecker {
  /// A hint only: "connected" is not "reachable" (zero balance, captive portals). The cloud timeout is the real guard.
  Future<bool> isOnline();
}

abstract interface class AuthGate {
  /// Signs in anonymously if needed and returns the uid. Lazy: never called at app start.
  Future<String> ensureSignedIn();
}

/// On-device classifier. Unavailable until Phase 6.
abstract interface class LocalClassifier {
  bool get isAvailable;
  Future<DiagnosisResult> classify(Uint8List jpeg, String cropId);
}

class NoLocalClassifier implements LocalClassifier {
  const NoLocalClassifier();
  @override
  bool get isAvailable => false;
  @override
  Future<DiagnosisResult> classify(Uint8List jpeg, String cropId) =>
      throw const OfflineModelMissing();
}

/// Orchestrates diagnosis: cloud first when allowed, on-device fallback for launch crops (Design §6.4, §6.5).
class DiagnosisService {
  DiagnosisService({
    required this.cloud,
    required this.local,
    required this.connectivity,
    required this.auth,
    required this.kb,
    required this.flags,
    this.reporter,
    this.analytics,
    this.cloudBudget = const Duration(seconds: 8),
  });

  final CloudDiagnosisClient cloud;
  final LocalClassifier local;
  final ConnectivityChecker connectivity;
  final AuthGate auth;
  final KnowledgeBase Function() kb;
  final RemoteFlags Function() flags;

  /// Where unexpected cloud problems (App Check or auth rejections) are logged for the developers.
  final ErrorReporter? reporter;
  final Analytics? analytics;

  /// Total time allowed for sign-in plus the cloud call, then the on-device fallback takes over.
  /// Needed because "connected" is not "reachable" (zero data balance, captive portals).
  final Duration cloudBudget;

  Future<DiagnosisOutcome> run(Uint8List preparedJpeg, CropSelection crop) async {
    final knowledge = kb();
    final isLaunchCrop = !crop.isOther && knowledge.supportsCrop(crop.id);
    final cloudAllowed = flags().cloudDiagnosisEnabled && await connectivity.isOnline();

    if (cloudAllowed) {
      try {
        final response = await (() async {
          await auth.ensureSignedIn();
          return cloud.diagnose(preparedJpeg, crop.param);
        })()
            .timeout(cloudBudget, onTimeout: () => throw const CloudTimeout());
        return _fromCloud(response, preparedJpeg, knowledge);
      } on DiagnosisFailure catch (f) {
        if (f is ServiceRejected) unawaited(_log(f, 'cloud call rejected (App Check or auth)'));
        if (isLaunchCrop && local.isAvailable) {
          _fellBack(failureName(f));
          return _onDevice(preparedJpeg, crop.id);
        }
        rethrow; // other crop, or nothing to fall back to: surface the failure
      } catch (e, st) {
        // Auth or any unexpected error behaves like a service problem, never a crash.
        unawaited(_log(e, 'unexpected cloud error', st));
        if (isLaunchCrop && local.isAvailable) {
          _fellBack('unexpected');
          return _onDevice(preparedJpeg, crop.id);
        }
        throw const ServerError('unexpected');
      }
    }
    if (!isLaunchCrop) throw const NeedsInternet();
    if (!local.isAvailable) throw const OfflineModelMissing();
    // Cloud was not even tried: offline or switched off remotely. Counted so the rollout can see how often it happens.
    _fellBack(flags().cloudDiagnosisEnabled ? 'offline' : 'cloud_disabled');
    return _onDevice(preparedJpeg, crop.id);
  }

  void _fellBack(String reason) {
    final a = analytics;
    if (a != null) Ev.fallbackToOnDevice(a, reason: reason);
  }

  Future<void> _log(Object e, String reason, [StackTrace? st]) async => reporter?.record(e, st, reason: reason);

  Future<DiagnosisOutcome> _onDevice(Uint8List jpeg, String cropId) async {
    final DiagnosisResult r;
    try {
      r = await local.classify(jpeg, cropId);
    } on DiagnosisFailure {
      rethrow;
    } catch (e, st) {
      unawaited(_log(e, 'on-device classification crashed', st));
      throw const OfflineModelMissing();
    }
    // A model label the KB does not know (model and KB out of step) must never reach the result screen.
    final known = !r.isDisease || kb()[r.diseaseId] != null;
    return _classifiedOrRetake(
      known ? r : DiagnosisResult(diseaseId: kUnknown, confidence: Confidence.low, source: r.source, imageIssue: r.imageIssue, kbSeq: r.kbSeq),
      jpeg,
    );
  }

  DiagnosisOutcome _fromCloud(CloudResponse r, Uint8List jpeg, KnowledgeBase knowledge) {
    switch (r) {
      case CloudGeneral():
        return GeneralAdvice(r.summaryBn, r.preventionBn, jpeg);
      case CloudClassified():
        // The server's KB can be newer than this app's: an id we do not know is shown as "unknown".
        final known = r.diseaseId == kHealthy || r.diseaseId == kUnknown || knowledge[r.diseaseId] != null;
        return _classifiedOrRetake(
          DiagnosisResult(
            diseaseId: known ? r.diseaseId : kUnknown,
            confidence: known ? r.confidence : Confidence.low,
            source: DiagnosisSource.cloud,
            imageIssue: r.imageIssue,
            kbSeq: knowledge.seq,
          ),
          jpeg,
        );
    }
  }

  /// "Unknown" with a photo problem is a retake request, not a diagnosis.
  DiagnosisOutcome _classifiedOrRetake(DiagnosisResult r, Uint8List jpeg) =>
      r.diseaseId == kUnknown && r.imageIssue != ImageIssue.none
          ? NeedsRetake(r.imageIssue)
          : Classified(r, jpeg);
}

/// Stable, low-cardinality name of a failure, for analytics.
String failureName(DiagnosisFailure f) => switch (f) {
      NeedsInternet() => 'needs_internet',
      OfflineModelMissing() => 'offline_model_missing',
      CloudTimeout() => 'cloud_timeout',
      DailyCapReached() => 'daily_cap',
      ServiceRejected() => 'service_rejected',
      ServerError() => 'server_error',
    };
