import 'dart:math' as math;

import '../diagnosis/domain/diagnosis_models.dart';
import '../diagnosis/domain/image_issue.dart';
import 'model_contract.dart';

class Thresholds {
  const Thresholds({required this.confHigh, required this.confMedium, required this.minCropMass});

  /// Score >= confHigh is "high", >= confMedium is "medium", otherwise "low" (Remote Config, calibrated in task 9.1).
  final double confHigh;
  final double confMedium;

  /// Minimum probability mass the model must put on the chosen crop's classes. Less means "this looks like
  /// another crop or not a plant".
  final double minCropMass;
}

class OfflineScore {
  const OfflineScore(this.diseaseId, this.confidence, this.imageIssue);
  final String diseaseId;
  final Confidence confidence;
  final ImageIssue imageIssue;

  @override
  bool operator ==(Object other) =>
      other is OfflineScore && other.diseaseId == diseaseId && other.confidence == confidence && other.imageIssue == imageIssue;
  @override
  int get hashCode => Object.hash(diseaseId, confidence, imageIssue);
  @override
  String toString() => 'OfflineScore($diseaseId, ${confidence.name}, ${imageIssue.name})';
}

/// Numerically stable softmax, for models that output logits.
List<double> softmax(List<double> logits) {
  final m = logits.reduce(math.max);
  final exps = [for (final v in logits) math.exp(v - m)];
  final sum = exps.fold<double>(0, (a, b) => a + b);
  return [for (final e in exps) e / sum];
}

/// Crop-masked scoring. The farmer already chose the crop, so only that crop's classes compete; the probability
/// mass the model puts anywhere else is the "wrong crop / not a plant" signal. The best class is scored by its
/// share of the crop's mass, so `confidence` is relative within the crop.
OfflineScore scoreForCrop({
  required List<double> probs,
  required List<ModelLabel> labels,
  required String crop,
  required Thresholds thresholds,
}) {
  const unknown = OfflineScore(kUnknown, Confidence.low, ImageIssue.none);
  if (probs.length != labels.length || probs.any((p) => p.isNaN || p.isInfinite || p < 0)) return unknown;

  final idx = [for (var i = 0; i < labels.length; i++) if (labels[i].crop == crop) i];
  if (idx.isEmpty) return unknown; // this model does not cover the crop

  final mass = idx.fold<double>(0, (a, i) => a + probs[i]);
  if (mass < thresholds.minCropMass) {
    return const OfflineScore(kUnknown, Confidence.low, ImageIssue.wrongCrop);
  }
  var best = idx.first;
  for (final i in idx) {
    if (probs[i] > probs[best]) best = i;
  }
  final score = probs[best] / mass;
  final confidence = score >= thresholds.confHigh
      ? Confidence.high
      : score >= thresholds.confMedium
          ? Confidence.medium
          : Confidence.low;
  return OfflineScore(labels[best].diseaseId, confidence, ImageIssue.none);
}
