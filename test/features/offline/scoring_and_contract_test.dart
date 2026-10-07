import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mather_sathi/features/diagnosis/domain/diagnosis_models.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';
import 'package:mather_sathi/features/offline/crop_scoring.dart';
import 'package:mather_sathi/features/offline/model_contract.dart';
import 'package:mather_sathi/features/offline/preprocess.dart';

import '../../support/offline_fakes.dart';

const _t = Thresholds(confHigh: 0.80, confMedium: 0.60, minCropMass: 0.50);

OfflineScore score(List<double> p, {String crop = 'rice', Thresholds t = _t, List<ModelLabel> labels = testLabels}) =>
    scoreForCrop(probs: p, labels: labels, crop: crop, thresholds: t);

String metaJson([Map<String, Object?> over = const {}]) => jsonEncode({
      'version': 'v1', 'file': 'crop_disease_v1.tflite', 'input_size': 224, 'input_type': 'float32', 'resize': 'bilinear',
      'normalization': 'zero_one', 'output': 'probabilities', 'labels': 5, ...over,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // the platform JPEG codec is used for preprocessing

  group('crop-masked scoring (task 6.3), fixed vectors', () {
    test('a confident disease: share of the crop mass decides the bucket', () {
      // mass on rice = 0.97; blast share = 0.90/0.97 = 0.93 -> high
      expect(score([0.90, 0.04, 0.02, 0.01, 0.03]), const OfflineScore('rice_blast', Confidence.high, ImageIssue.none));
    });

    test('medium and low buckets use the thresholds on the renormalised score', () {
      // blast 0.60 of 0.95 mass = 0.63 -> medium
      expect(score([0.60, 0.25, 0.05, 0.05, 0.05]).confidence, Confidence.medium);
      // blast 0.40 of 0.95 = 0.42 -> low
      expect(score([0.40, 0.35, 0.10, 0.10, 0.05]).confidence, Confidence.low);
    });

    test('score is relative within the crop: a small absolute probability can still be high', () {
      // only 0.55 of the mass is on rice (>= minCropMass), blast holds 0.50 of it -> 0.91 -> high
      expect(score([0.50, 0.02, 0.02, 0.01, 0.45]).confidence, Confidence.high);
    });

    test('other crops\' classes never compete, even when they score highest', () {
      final s = score([0.30, 0.10, 0.05, 0.05, 0.50]);
      expect(s.diseaseId, 'rice_blast', reason: 'potato_early_blight has the top raw probability but is the wrong crop');
    });

    test('too little mass on the chosen crop means wrong crop / not a plant', () {
      expect(score([0.05, 0.02, 0.01, 0.01, 0.91]), const OfflineScore(kUnknown, Confidence.low, ImageIssue.wrongCrop));
      // exactly at the minimum is accepted, just below is not
      expect(score([0.30, 0.10, 0.05, 0.05, 0.50]).imageIssue, ImageIssue.none);
      expect(score([0.30, 0.10, 0.05, 0.04, 0.51]).imageIssue, ImageIssue.wrongCrop);
    });

    test('healthy and unknown classes are valid winners', () {
      expect(score([0.02, 0.02, 0.92, 0.02, 0.02]).diseaseId, kHealthy);
      expect(score([0.02, 0.02, 0.02, 0.92, 0.02]), const OfflineScore(kUnknown, Confidence.high, ImageIssue.none));
    });

    test('bucket boundaries are inclusive', () {
      // exactly 0.8 and exactly 0.6 of a mass of 1.0
      expect(score([0.8, 0.2, 0, 0, 0]).confidence, Confidence.high);
      expect(score([0.6, 0.4, 0, 0, 0]).confidence, Confidence.medium);
      expect(score([0.59, 0.41, 0, 0, 0]).confidence, Confidence.low);
    });

    test('thresholds are parameters, not constants', () {
      const strict = Thresholds(confHigh: 0.95, confMedium: 0.90, minCropMass: 0.99);
      expect(score([0.9, 0.05, 0.02, 0.01, 0.02], t: strict).imageIssue, ImageIssue.wrongCrop);
    });

    test('garbage output is unknown/low, never a crash or a confident answer', () {
      final unknown = const OfflineScore(kUnknown, Confidence.low, ImageIssue.none);
      expect(score([double.nan, 0.5, 0.2, 0.2, 0.1]), unknown);
      expect(score([double.infinity, 0, 0, 0, 0]), unknown);
      expect(score([-0.1, 0.5, 0.3, 0.2, 0.1]), unknown);
      expect(score([0.5, 0.5]), unknown, reason: 'length does not match the labels');
      expect(score([0, 0, 0, 0, 0]).imageIssue, ImageIssue.wrongCrop, reason: 'all-zero output has no mass on the crop');
    });

    test('a crop the model does not cover is unknown', () {
      expect(score([0.9, 0.05, 0.02, 0.01, 0.02], crop: 'jute'), const OfflineScore(kUnknown, Confidence.low, ImageIssue.none));
    });

    test('softmax: sums to 1, stable for huge logits, order preserved', () {
      final p = softmax([2.0, 1.0, 0.1]);
      expect(p.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-12));
      expect(p[0], greaterThan(p[1]));
      final big = softmax([1000, 1001, 999]);
      expect(big.every((v) => v.isFinite), isTrue);
      expect(big.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-12));
    });
  });

  group('model contract', () {
    test('parses a valid model_meta.json', () {
      final m = ModelMeta.parse(metaJson());
      expect([m.inputSize, m.inputType, m.resize, m.normalization, m.outputIsLogits, m.labelCount, m.file],
          [224, ModelInputType.float32, ResizeMode.bilinear, Normalization.zeroOne, false, 5, 'crop_disease_v1.tflite']);
    });

    for (final bad in <String, Map<String, Object?>>{
      'unknown dtype': {'input_type': 'int8'},
      'unknown resize': {'resize': 'nearest'},
      'unknown normalization': {'normalization': 'foo'},
      'unknown output': {'output': 'scores'},
      'tiny size': {'input_size': 8},
      'one label': {'labels': 1},
      'path in file': {'file': '../model.tflite'},
      'uint8 with normalization': {'input_type': 'uint8'},
      'float32 without normalization': {'normalization': 'none'},
    }.entries) {
      test('rejects: ${bad.key}', () => expect(() => ModelMeta.parse(metaJson(bad.value)), throwsA(isA<ModelContractException>())));
    }

    test('rejects broken JSON and a missing field', () {
      expect(() => ModelMeta.parse('{ nope'), throwsA(isA<ModelContractException>()));
      expect(() => ModelMeta.parse('{}'), throwsA(isA<ModelContractException>()));
    });

    test('labels.json: order is the output order; bad shapes are rejected', () {
      final l = parseLabels('[{"disease_id":"rice_blast","crop":"rice"},{"disease_id":"healthy","crop":"rice"}]');
      expect([l[0].diseaseId, l[1].diseaseId, l[1].crop], ['rice_blast', 'healthy', 'rice']);
      for (final bad in ['[]', '{}', '[{"disease_id":"x"}]', '[1]', 'nope']) {
        expect(() => parseLabels(bad), throwsA(isA<ModelContractException>()), reason: bad);
      }
    });
  });

  group('preprocessing parity with the training pipeline (tools/model_check/preprocess_reference.py)', () {
    final jpeg = File('test/fixtures/offline/parity_input.jpg').readAsBytesSync();

    List<double> reference(String resize, String norm) =>
        (jsonDecode(File('test/fixtures/offline/ref_${resize}_${norm}_16.json').readAsStringSync()) as List).cast<num>().map((e) => e.toDouble()).toList();

    for (final (resize, mode) in [('area', ResizeMode.area), ('bilinear', ResizeMode.bilinear)]) {
      for (final (norm, n, tol) in [('zero_one', Normalization.zeroOne, 0.004), ('imagenet', Normalization.imagenet, 0.02)]) {
        test('$resize + $norm matches the Python reference', () async {
          final out = await preprocessJpeg((jpeg: jpeg, size: 16, type: ModelInputType.float32, resize: mode, norm: n)) as Float32List;
          final ref = reference(resize, norm);
          expect(out.length, ref.length);
          var maxDiff = 0.0, sum = 0.0;
          for (var i = 0; i < out.length; i++) {
            final d = (out[i] - ref[i]).abs();
            sum += d;
            if (d > maxDiff) maxDiff = d;
          }
          // The platform decoder is bit-identical to PIL; what remains is below one 8-bit step (PIL rounds the resized area image to uint8).
          expect(maxDiff, lessThan(tol), reason: 'max abs diff $maxDiff');
          expect(sum / out.length, lessThan(tol / 2));
        });
      }
    }

    test('the two resize modes really differ (so the meta field matters)', () async {
      Future<Float32List> run(ResizeMode m) async =>
          await preprocessJpeg((jpeg: jpeg, size: 16, type: ModelInputType.float32, resize: m, norm: Normalization.zeroOne)) as Float32List;
      final a = await run(ResizeMode.area), b = await run(ResizeMode.bilinear);
      var diff = 0.0;
      for (var i = 0; i < a.length; i++) {
        diff += (a[i] - b[i]).abs();
      }
      expect(diff / a.length, greaterThan(0.005));
    });

    test('normalization formulas on a flat colour', () async {
      final flat = Uint8List.fromList(img.encodeJpg(img.Image(width: 32, height: 32)..clear(img.ColorRgb8(200, 100, 50)), quality: 100));
      Future<List<double>> f(Normalization n) async =>
          ((await preprocessJpeg((jpeg: flat, size: 4, type: ModelInputType.float32, resize: ResizeMode.area, norm: n))) as Float32List).take(3).toList();
      expect((await f(Normalization.zeroOne))[0], closeTo(200 / 255, 0.02));
      expect((await f(Normalization.minusOneOne))[0], closeTo(200 / 127.5 - 1, 0.03));
      expect((await f(Normalization.imagenet))[0], closeTo((200 / 255 - 0.485) / 0.229, 0.1));
      expect((await f(Normalization.none))[0], closeTo(200, 4));
    });

    test('uint8 input: raw 0..255 bytes, NHWC length', () async {
      final out = await preprocessJpeg((jpeg: jpeg, size: 16, type: ModelInputType.uint8, resize: ResizeMode.area, norm: Normalization.none));
      expect(out, isA<Uint8List>());
      expect((out as Uint8List).length, 16 * 16 * 3);
    });

    test('output length is size*size*3 for a non-square source, and an undecodable JPEG throws', () async {
      final wide = Uint8List.fromList(img.encodeJpg(img.Image(width: 100, height: 40)));
      final out = await preprocessJpeg((jpeg: wide, size: 8, type: ModelInputType.float32, resize: ResizeMode.bilinear, norm: Normalization.zeroOne));
      expect((out as Float32List).length, 8 * 8 * 3);
      await expectLater(
        preprocessJpeg((jpeg: Uint8List.fromList([1, 2, 3]), size: 8, type: ModelInputType.float32, resize: ResizeMode.area, norm: Normalization.zeroOne)),
        throwsA(anything),
      );
    });
  });
}
