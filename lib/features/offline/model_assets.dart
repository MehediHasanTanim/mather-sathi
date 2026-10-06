import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_reporter.dart';
import '../diagnosis/diagnosis_service.dart';
import '../kb/kb_provider.dart';
import '../../core/flags/remote_flags.dart';
import 'crop_scoring.dart';
import 'model_contract.dart';
import 'model_runner.dart';
import 'tflite_classifier.dart';

/// The validated offline-model files. Null means "no usable offline model": the app then behaves exactly like a
/// cloud-only build (Design: cloud-only first, offline later).
class ModelAssets {
  const ModelAssets({required this.meta, required this.labels});
  final ModelMeta meta;
  final List<ModelLabel> labels;

  static const dir = 'assets/models';

  /// Cheap startup probe: reads the two small JSON files and checks the `.tflite` is bundled. Does NOT load the
  /// interpreter. Missing files return null quietly; present-but-invalid files are reported and also return null.
  static Future<ModelAssets?> probe(AssetBundle bundle, ErrorReporter reporter) async {
    final String metaJson, labelsJson;
    try {
      metaJson = await bundle.loadString('$dir/model_meta.json');
      labelsJson = await bundle.loadString('$dir/labels.json');
    } catch (_) {
      return null; // not bundled: normal for cloud-only builds
    }
    try {
      final meta = ModelMeta.parse(metaJson);
      final labels = parseLabels(labelsJson);
      if (labels.length != meta.labelCount) {
        throw ModelContractException('labels.json has ${labels.length} labels, model_meta.json says ${meta.labelCount}');
      }
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      if (!manifest.listAssets().contains('$dir/${meta.file}')) {
        throw ModelContractException('$dir/${meta.file} is not bundled');
      }
      return ModelAssets(meta: meta, labels: labels);
    } catch (e, st) {
      await reporter.record(e, st, reason: 'offline model files are invalid, offline mode disabled');
      return null;
    }
  }
}

/// Set in `bootstrap()` from [ModelAssets.probe]; null in cloud-only builds and in tests.
final modelAssetsProvider = Provider<ModelAssets?>((ref) => null);

final localClassifierProvider = Provider<LocalClassifier>((ref) {
  final assets = ref.watch(modelAssetsProvider);
  if (assets == null) return const NoLocalClassifier();
  final classifier = TfliteClassifier(
    meta: assets.meta,
    labels: assets.labels,
    loadRunner: () => TfliteModelRunner.load('${ModelAssets.dir}/${assets.meta.file}', assets.meta),
    thresholds: () {
      final f = ref.read(remoteFlagsProvider);
      return Thresholds(confHigh: f.confHigh, confMedium: f.confMedium, minCropMass: f.minCropMass);
    },
    kbSeq: () => ref.read(kbProvider).value?.seq ?? 0,
    reporter: ref.read(errorReporterProvider),
  );
  ref.onDispose(classifier.release);
  return classifier;
});
