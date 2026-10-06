import 'dart:typed_data';

import 'image_issue.dart';

enum Confidence { high, medium, low }

enum DiagnosisSource { cloud, onDevice }

const kHealthy = 'healthy';
const kUnknown = 'unknown';

/// Result of classifying into the KB's closed set.
class DiagnosisResult {
  const DiagnosisResult({
    required this.diseaseId,
    required this.confidence,
    required this.source,
    required this.imageIssue,
    required this.kbSeq,
  });

  /// KB id, [kHealthy] or [kUnknown].
  final String diseaseId;
  final Confidence confidence;
  final DiagnosisSource source;
  final ImageIssue imageIssue;
  final int kbSeq;

  bool get isDisease => diseaseId != kHealthy && diseaseId != kUnknown;
}

sealed class DiagnosisOutcome {
  const DiagnosisOutcome();
}

class Classified extends DiagnosisOutcome {
  const Classified(this.result, this.preparedJpeg);
  final DiagnosisResult result;
  final Uint8List preparedJpeg;
}

/// "Other crop" path: general Bangla text, never medicines or doses.
class GeneralAdvice extends DiagnosisOutcome {
  const GeneralAdvice(this.summaryBn, this.preventionBn, this.preparedJpeg);
  final String summaryBn;
  final List<String> preventionBn;
  final Uint8List preparedJpeg;
}

class NeedsRetake extends DiagnosisOutcome {
  const NeedsRetake(this.issue);
  final ImageIssue issue;
}

sealed class DiagnosisFailure implements Exception {
  const DiagnosisFailure();
}

class NeedsInternet extends DiagnosisFailure {
  const NeedsInternet();
}

class OfflineModelMissing extends DiagnosisFailure {
  const OfflineModelMissing();
}

class CloudTimeout extends DiagnosisFailure {
  const CloudTimeout();
}

class DailyCapReached extends DiagnosisFailure {
  const DailyCapReached();
}

/// App Check or auth rejected the call.
class ServiceRejected extends DiagnosisFailure {
  const ServiceRejected();
}

class ServerError extends DiagnosisFailure {
  const ServerError(this.code);
  final String code;
}
