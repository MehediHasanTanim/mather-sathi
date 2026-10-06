// On-device parity check (plan task 6.5). Run on a phone or emulator with the real model bundled:
//
//   1. python3 tools/model_check/export_model_outputs.py --images integration_test/parity --out integration_test/parity/expected.json
//   2. flutter test integration_test/parity_test.dart -d <device> --flavor dev
//
// It runs the app's real preprocessing and TFLite on the same images and compares with the Python reference.
// Float model: probabilities within a small tolerance. int8 model: same top-1 class on every image.
// A mismatch almost always means the preprocessing differs from training (resize mode, normalisation, channel order).
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mather_sathi/features/offline/model_assets.dart';
import 'package:mather_sathi/features/offline/model_contract.dart';
import 'package:mather_sathi/features/offline/model_runner.dart';
import 'package:mather_sathi/features/offline/preprocess.dart';

import '../test/support/diagnosis_fakes.dart' show FakeReporter;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app outputs match the Python reference on the parity images', (tester) async {
    final assets = await ModelAssets.probe(rootBundle, FakeReporter());
    if (assets == null) {
      // ignore: avoid_print
      print('No offline model bundled: parity check skipped (cloud-only build).');
      return;
    }
    final expected = jsonDecode(await rootBundle.loadString('integration_test/parity/expected.json')) as Map<String, dynamic>;
    final runner = await TfliteModelRunner.load('${ModelAssets.dir}/${assets.meta.file}', assets.meta);
    final isFloat = assets.meta.inputType == ModelInputType.float32 && !assets.meta.outputIsLogits;
    var mismatches = 0;

    for (final entry in expected.entries) {
      final jpeg = (await rootBundle.load('integration_test/parity/${entry.key}')).buffer.asUint8List();
      final input = await preprocessJpeg((
        jpeg: jpeg, size: assets.meta.inputSize, type: assets.meta.inputType, resize: assets.meta.resize, norm: assets.meta.normalization,
      ));
      final got = await runner.run(input);
      final want = [for (final v in entry.value as List) (v as num).toDouble()];
      expect(got.length, want.length, reason: entry.key);

      int argmax(List<double> p) => p.indexOf(p.reduce((a, b) => a > b ? a : b));
      if (argmax(got) != argmax(want)) mismatches++;
      if (isFloat) {
        for (var i = 0; i < got.length; i++) {
          expect(got[i], closeTo(want[i], 0.02), reason: '${entry.key} class $i');
        }
      }
    }
    expect(mismatches, 0, reason: 'top-1 must agree with the Python reference on every image');
    await runner.close();
  });
}
