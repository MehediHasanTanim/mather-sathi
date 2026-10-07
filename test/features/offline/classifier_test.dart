import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/errors/error_reporter.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/capture/domain/crop_selection.dart';
import 'package:mather_sathi/features/diagnosis/diagnosis_service.dart';
import 'package:mather_sathi/features/diagnosis/domain/diagnosis_models.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';
import 'package:mather_sathi/features/offline/crop_scoring.dart';
import 'package:mather_sathi/features/offline/memory_guard.dart';
import 'package:mather_sathi/features/offline/model_assets.dart';
import 'package:mather_sathi/features/offline/model_contract.dart';
import 'package:mather_sathi/features/offline/preprocess.dart';
import 'package:mather_sathi/features/offline/tflite_classifier.dart';

import '../../support/diagnosis_fakes.dart';
import '../../support/offline_fakes.dart';

final _jpeg = Uint8List.fromList([1, 2, 3]);
const _thresholds = Thresholds(confHigh: 0.8, confMedium: 0.6, minCropMass: 0.5);

class _Probe {
  _Probe(this.runner, {ModelMeta? meta, this.reporter}) {
    classifier = TfliteClassifier(
      meta: meta ?? testMeta(),
      labels: testLabels,
      loadRunner: () async {
        loads++;
        if (failLoad) throw Exception('cannot load model');
        await loadGate?.future;
        return runner;
      },
      thresholds: () => _thresholds,
      kbSeq: () => 7,
      reporter: reporter ?? FakeReporter(),
      preprocess: (a) async {
        args.add(a);
        return noopInput(a.size * a.size * 3);
      },
    );
  }
  final FakeRunner runner;
  final ErrorReporter? reporter;
  late final TfliteClassifier classifier;
  final args = <PreprocessArgs>[];
  int loads = 0;
  bool failLoad = false;
  Completer<void>? loadGate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TfliteClassifier (task 6.2/6.3)', () {
    test('classifies for the chosen crop and tags the result as on-device with the KB seq', () async {
      final p = _Probe(FakeRunner([0.90, 0.04, 0.02, 0.01, 0.03]));
      final r = await p.classifier.classify(_jpeg, 'rice');
      expect([r.diseaseId, r.confidence, r.source, r.imageIssue, r.kbSeq],
          ['rice_blast', Confidence.high, DiagnosisSource.onDevice, ImageIssue.none, 7]);
    });

    test('the model is NOT loaded until the first offline classification, then loaded once', () async {
      final p = _Probe(FakeRunner([0.9, 0.04, 0.02, 0.01, 0.03]));
      expect(p.loads, 0, reason: 'constructing the classifier must not load the interpreter');
      await p.classifier.classify(_jpeg, 'rice');
      await p.classifier.classify(_jpeg, 'rice');
      expect(p.loads, 1);
    });

    test('concurrent first calls share one load (single-flight)', () async {
      final p = _Probe(FakeRunner([0.9, 0.04, 0.02, 0.01, 0.03]))..loadGate = Completer<void>();
      final futures = [for (var i = 0; i < 3; i++) p.classifier.classify(_jpeg, 'rice')];
      await Future<void>.delayed(Duration.zero);
      p.loadGate!.complete();
      await Future.wait(futures);
      expect(p.loads, 1);
      expect(p.runner.runs, 3);
    });

    test('preprocessing follows model_meta.json (size, dtype, resize, normalisation)', () async {
      final meta = testMeta(size: 12, type: ModelInputType.uint8, resize: ResizeMode.bilinear, norm: Normalization.none);
      final p = _Probe(FakeRunner([0.9, 0.04, 0.02, 0.01, 0.03]), meta: meta);
      await p.classifier.classify(_jpeg, 'rice');
      expect(p.args.single.size, 12);
      expect(p.args.single.type, ModelInputType.uint8);
      expect(p.args.single.resize, ResizeMode.bilinear);
      expect(p.args.single.norm, Normalization.none);
      expect(p.args.single.jpeg, _jpeg);
    });

    test('a logits model gets a softmax before scoring', () async {
      // logits whose softmax is ~[0.95, 0.02, 0.01, 0.01, 0.01]
      final p = _Probe(FakeRunner([5.0, 1.2, 0.5, 0.5, 0.5]), meta: testMeta(logits: true));
      final r = await p.classifier.classify(_jpeg, 'rice');
      expect([r.diseaseId, r.confidence], ['rice_blast', Confidence.high]);
    });

    test('the other crop\'s classes are masked out and a wrong-crop photo is flagged', () async {
      final p = _Probe(FakeRunner([0.02, 0.01, 0.01, 0.01, 0.95]));
      final r = await p.classifier.classify(_jpeg, 'rice');
      expect([r.diseaseId, r.imageIssue], [kUnknown, ImageIssue.wrongCrop]);
    });

    test('a failed load becomes OfflineModelMissing, is reported, and is retried next time', () async {
      final reporter = FakeReporter();
      final p = _Probe(FakeRunner([0.9, 0.04, 0.02, 0.01, 0.03]), reporter: reporter)..failLoad = true;
      await expectLater(p.classifier.classify(_jpeg, 'rice'), throwsA(isA<OfflineModelMissing>()));
      expect(reporter.reports.single, contains('failed to load'));
      p.failLoad = false;
      expect((await p.classifier.classify(_jpeg, 'rice')).diseaseId, 'rice_blast');
      expect(p.loads, 2);
    });

    test('a crash while running or preprocessing is OfflineModelMissing and reported', () async {
      final reporter = FakeReporter();
      final p = _Probe(FakeRunner([0.9, 0.04, 0.02, 0.01, 0.03]) ..throwOnRun = StateError('native crash'), reporter: reporter);
      await expectLater(p.classifier.classify(_jpeg, 'rice'), throwsA(isA<OfflineModelMissing>()));
      expect(reporter.reports.single, contains('classification failed'));
    });

    test('release closes the interpreter; the next call reloads it', () async {
      final p = _Probe(FakeRunner([0.9, 0.04, 0.02, 0.01, 0.03]));
      await p.classifier.classify(_jpeg, 'rice');
      await p.classifier.release();
      expect(p.runner.closed, isTrue);
      await p.classifier.classify(_jpeg, 'rice');
      expect(p.loads, 2);
    });

    test('release without a loaded model is a no-op', () async {
      await _Probe(FakeRunner([0.9, 0.04, 0.02, 0.01, 0.03])).classifier.release();
    });

    test('low-memory signal frees the model (MemoryPressureGuard)', () async {
      final p = _Probe(FakeRunner([0.9, 0.04, 0.02, 0.01, 0.03]));
      await p.classifier.classify(_jpeg, 'rice');
      MemoryPressureGuard(() => p.classifier).didHaveMemoryPressure();
      await Future<void>.delayed(Duration.zero);
      expect(p.runner.closed, isTrue);
      MemoryPressureGuard(() => const NoLocalClassifier()).didHaveMemoryPressure(); // must not throw
    });
  });

  group('DiagnosisService with the real classifier (fallback matrix cases 2, 4, 6, 7)', () {
    DiagnosisService svc(_Probe p, {bool online = true, Object? cloudThrows, FakeReporter? reporter}) => DiagnosisService(
          cloud: fakeCloud(response: cloudClassified('rice_brown_spot'), throws: cloudThrows),
          local: p.classifier,
          connectivity: FakeConnectivity(online),
          auth: FakeAuth(),
          kb: testKb,
          flags: () => RemoteFlags.defaults,
          reporter: reporter,
        );
    // testKb has rice_blast and potato_early_blight
    final blast = [0.90, 0.04, 0.02, 0.01, 0.03];

    test('2: cloud timeout falls back to the on-device result', () async {
      final o = await svc(_Probe(FakeRunner(blast)), cloudThrows: const CloudTimeout()).run(_jpeg, const CropSelection('rice')) as Classified;
      expect([o.result.diseaseId, o.result.source], ['rice_blast', DiagnosisSource.onDevice]);
    });

    test('4: daily cap falls back too', () async {
      final o = await svc(_Probe(FakeRunner(blast)), cloudThrows: const DailyCapReached()).run(_jpeg, const CropSelection('rice'));
      expect((o as Classified).result.source, DiagnosisSource.onDevice);
    });

    test('6: a rejected service falls back and is logged', () async {
      final reporter = FakeReporter();
      final o = await svc(_Probe(FakeRunner(blast)), cloudThrows: const ServiceRejected(), reporter: reporter).run(_jpeg, const CropSelection('rice'));
      expect((o as Classified).result.source, DiagnosisSource.onDevice);
      expect(reporter.reports, hasLength(1));
    });

    test('7: offline works with no cloud call at all', () async {
      final o = await svc(_Probe(FakeRunner(blast)), online: false).run(_jpeg, const CropSelection('rice')) as Classified;
      expect([o.result.diseaseId, o.result.source], ['rice_blast', DiagnosisSource.onDevice]);
    });

    test('9: an other crop offline still needs the internet, model or not', () async {
      await expectLater(svc(_Probe(FakeRunner(blast)), online: false).run(_jpeg, CropSelection.other('ধনেপাতা')), throwsA(isA<NeedsInternet>()));
    });

    test('a wrong-crop photo offline becomes a retake request', () async {
      final o = await svc(_Probe(FakeRunner([0.02, 0.01, 0.01, 0.01, 0.95])), online: false).run(_jpeg, const CropSelection('rice'));
      expect((o as NeedsRetake).issue, ImageIssue.wrongCrop);
    });

    test('a model label the KB does not know is shown as unknown, never as a ghost disease', () async {
      // rice_brown_spot is a valid model label but missing from the test KB
      final o = await svc(_Probe(FakeRunner([0.02, 0.90, 0.02, 0.02, 0.04])), online: false).run(_jpeg, const CropSelection('rice')) as Classified;
      expect([o.result.diseaseId, o.result.confidence], [kUnknown, Confidence.low]);
    });

    test('a model that fails to load offline is OfflineModelMissing', () async {
      final p = _Probe(FakeRunner(blast))..failLoad = true;
      await expectLater(svc(p, online: false).run(_jpeg, const CropSelection('rice')), throwsA(isA<OfflineModelMissing>()));
    });
  });

  group('ModelAssets.probe (startup, no interpreter)', () {
    final reporter = FakeReporter();
    setUp(() => reporter.reports.clear());

    Map<String, Object?> meta([Map<String, Object?> over = const {}]) => {
          'version': 'v1', 'file': 'crop_disease_v1.tflite', 'input_size': 224, 'input_type': 'float32', 'resize': 'area',
          'normalization': 'zero_one', 'output': 'probabilities', 'labels': 2, ...over,
        };
    const labels = [{'disease_id': 'rice_blast', 'crop': 'rice'}, {'disease_id': 'healthy', 'crop': 'rice'}];

    AssetBundle bundle(Map<String, Object?> files, {bool tflite = true}) => _Bundle({
          for (final e in files.entries) 'assets/models/${e.key}': utf8.encode(e.value is String ? e.value! as String : jsonEncode(e.value)),
          if (tflite) 'assets/models/crop_disease_v1.tflite': [0, 1, 2],
        });

    test('no model files: quietly null (cloud-only build), nothing reported', () async {
      expect(await ModelAssets.probe(_Bundle({}), reporter), isNull);
      expect(reporter.reports, isEmpty);
    });

    test('a complete, consistent handoff is accepted', () async {
      final a = await ModelAssets.probe(bundle({'model_meta.json': meta(), 'labels.json': labels}), reporter);
      expect(a, isNotNull);
      expect(a!.meta.inputSize, 224);
      expect(a.labels, hasLength(2));
      expect(reporter.reports, isEmpty);
    });

    for (final c in <String, (Map<String, Object?>, bool)>{
      'label count differs from the meta': ({'model_meta.json': meta({'labels': 3}), 'labels.json': labels}, true),
      'invalid meta': ({'model_meta.json': meta({'resize': 'nearest'}), 'labels.json': labels}, true),
      'malformed labels': ({'model_meta.json': meta(), 'labels.json': '[{"nope":1}]'}, true),
      'the .tflite is not bundled': ({'model_meta.json': meta(), 'labels.json': labels}, false),
    }.entries) {
      test('${c.key}: offline is disabled and the problem is reported', () async {
        final a = await ModelAssets.probe(bundle(c.value.$1, tflite: c.value.$2), reporter);
        expect(a, isNull);
        expect(reporter.reports.single, contains('offline mode disabled'));
      });
    }
  });

  group('providers', () {
    test('without model assets the app is cloud-only (NoLocalClassifier, offline unavailable)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(localClassifierProvider).isAvailable, isFalse);
    });

    test('with model assets a classifier is built, without loading the interpreter', () {
      final c = ProviderContainer(overrides: [
        modelAssetsProvider.overrideWithValue(ModelAssets(meta: testMeta(), labels: testLabels)),
      ]);
      addTearDown(c.dispose);
      expect(c.read(localClassifierProvider), isA<TfliteClassifier>());
      expect(c.read(localClassifierProvider).isAvailable, isTrue);
    });
  });
}

/// Asset bundle backed by a map, including the binary asset manifest the real bundle provides.
class _Bundle extends CachingAssetBundle {
  _Bundle(Map<String, List<int>> files) : _files = files;
  final Map<String, List<int>> _files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final k in _files.keys) k: [<String, Object?>{'asset': k}],
      })!;
    }
    final bytes = _files[key];
    if (bytes == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
