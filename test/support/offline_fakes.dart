import 'dart:typed_data';

import 'package:mather_sathi/features/offline/model_contract.dart';
import 'package:mather_sathi/features/offline/model_runner.dart';

ModelMeta testMeta({
  int size = 8,
  ModelInputType type = ModelInputType.float32,
  ResizeMode resize = ResizeMode.area,
  Normalization norm = Normalization.zeroOne,
  bool logits = false,
  int labels = 5,
}) =>
    ModelMeta(version: 'v1', file: 'crop_disease_v1.tflite', inputSize: size, inputType: type, resize: resize, normalization: norm, outputIsLogits: logits, labelCount: labels);

/// rice: blast, brown_spot, healthy, unknown   potato: late_blight (5 outputs)
const testLabels = [
  ModelLabel(diseaseId: 'rice_blast', crop: 'rice'),
  ModelLabel(diseaseId: 'rice_brown_spot', crop: 'rice'),
  ModelLabel(diseaseId: 'healthy', crop: 'rice'),
  ModelLabel(diseaseId: 'unknown', crop: 'rice'),
  ModelLabel(diseaseId: 'potato_early_blight', crop: 'potato'),
];

class FakeRunner implements ModelRunner {
  FakeRunner(this.output);
  List<double> output;
  Object? lastInput;
  int runs = 0;
  bool closed = false;
  Object? throwOnRun;

  @override
  Future<List<double>> run(Object input) async {
    runs++;
    lastInput = input;
    if (throwOnRun != null) throw throwOnRun!;
    return output;
  }

  @override
  Future<void> close() async => closed = true;
}

Uint8List noopInput(int n) => Uint8List(n);
