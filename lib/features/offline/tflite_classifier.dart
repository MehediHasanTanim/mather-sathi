import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/errors/error_reporter.dart';
import '../diagnosis/diagnosis_service.dart';
import '../diagnosis/domain/diagnosis_models.dart';
import 'crop_scoring.dart';
import 'model_contract.dart';
import 'model_runner.dart';
import 'preprocess.dart';

/// On-device classifier: preprocess in an isolate, run TFLite, score only the chosen crop's classes.
/// The interpreter loads lazily on the first offline need and can be released under memory pressure.
class TfliteClassifier implements LocalClassifier {
  TfliteClassifier({
    required this.meta,
    required this.labels,
    required this._loadRunner,
    required this.thresholds,
    required this.kbSeq,
    required this.reporter,
    Future<Object> Function(PreprocessArgs)? preprocess,
  }) : _preprocess = preprocess ?? preprocessJpeg;

  final ModelMeta meta;
  final List<ModelLabel> labels;
  final Thresholds Function() thresholds;
  final int Function() kbSeq;
  final ErrorReporter reporter;
  final Future<ModelRunner> Function() _loadRunner;
  final Future<Object> Function(PreprocessArgs) _preprocess;

  Future<ModelRunner>? _runner;

  /// True once the model files passed validation at startup (see `ModelAssets`). The interpreter itself is not loaded yet.
  @override
  bool get isAvailable => true;

  /// Single-flight lazy load. A failed load is reported and retried on the next call.
  Future<ModelRunner> _ensureRunner() {
    return _runner ??= _loadRunner().catchError((Object e, StackTrace st) {
      _runner = null;
      unawaited(reporter.record(e, st, reason: 'offline model failed to load'));
      throw const OfflineModelMissing();
    });
  }

  @override
  Future<DiagnosisResult> classify(Uint8List jpeg, String cropId) async {
    final runner = await _ensureRunner();
    try {
      final input = await _preprocess((jpeg: jpeg, size: meta.inputSize, type: meta.inputType, resize: meta.resize, norm: meta.normalization));
      var out = await runner.run(input);
      if (meta.outputIsLogits) out = softmax(out);
      final s = scoreForCrop(probs: out, labels: labels, crop: cropId, thresholds: thresholds());
      return DiagnosisResult(
        diseaseId: s.diseaseId,
        confidence: s.confidence,
        source: DiagnosisSource.onDevice,
        imageIssue: s.imageIssue,
        kbSeq: kbSeq(),
      );
    } on OfflineModelMissing {
      rethrow;
    } catch (e, st) {
      unawaited(reporter.record(e, st, reason: 'offline classification failed'));
      throw const OfflineModelMissing();
    }
  }

  /// Frees the interpreter (low-memory signal). The next classify reloads it.
  Future<void> release() async {
    final r = _runner;
    _runner = null;
    if (r != null) await (await r).close();
  }
}
