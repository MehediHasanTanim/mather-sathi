import 'dart:typed_data';

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
  /// Signs in anonymously if needed. Lazy: never called at app start.
  Future<void> ensureSignedIn();
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
  });

  final CloudDiagnosisClient cloud;
  final LocalClassifier local;
  final ConnectivityChecker connectivity;
  final AuthGate auth;
  final KnowledgeBase Function() kb;
  final RemoteFlags Function() flags;

  Future<DiagnosisOutcome> run(Uint8List preparedJpeg, CropSelection crop) async {
    final knowledge = kb();
    final isLaunchCrop = !crop.isOther && knowledge.supportsCrop(crop.id);
    final cloudAllowed = flags().cloudDiagnosisEnabled && await connectivity.isOnline();

    if (cloudAllowed) {
      try {
        await auth.ensureSignedIn();
        return _fromCloud(await cloud.diagnose(preparedJpeg, crop.param), preparedJpeg, knowledge);
      } on DiagnosisFailure {
        if (isLaunchCrop && local.isAvailable) return _onDevice(preparedJpeg, crop.id);
        rethrow; // other crop, or nothing to fall back to: surface the failure
      } catch (_) {
        // Auth or any unexpected error behaves like a service problem, never a crash.
        if (isLaunchCrop && local.isAvailable) return _onDevice(preparedJpeg, crop.id);
        throw const ServerError('unexpected');
      }
    }
    if (!isLaunchCrop) throw const NeedsInternet();
    if (!local.isAvailable) throw const OfflineModelMissing();
    return _onDevice(preparedJpeg, crop.id);
  }

  Future<DiagnosisOutcome> _onDevice(Uint8List jpeg, String cropId) async {
    final r = await local.classify(jpeg, cropId);
    return _classifiedOrRetake(r, jpeg);
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
