
import 'package:tflite_flutter/tflite_flutter.dart';

import 'model_contract.dart';

/// Runs the network on preprocessed input and returns one value per label. The seam that keeps the TFLite
/// native library out of unit tests.
abstract interface class ModelRunner {
  /// [input] is a flat NHWC [Float32List] or [Uint8List] as built by `preprocessJpeg`.
  Future<List<double>> run(Object input);
  Future<void> close();
}

/// TFLite on a background isolate, 2 threads. Verifies the model against `model_meta.json` before first use.
class TfliteModelRunner implements ModelRunner {
  TfliteModelRunner._(this._interpreter, this._isolate, this._meta, this._outputType, this._scale, this._zeroPoint);

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;
  final ModelMeta _meta;
  final TensorType _outputType;
  final double _scale;
  final int _zeroPoint;

  static Future<TfliteModelRunner> load(String asset, ModelMeta meta) async {
    final interpreter = await Interpreter.fromAsset(asset, options: InterpreterOptions()..threads = 2);
    try {
      final input = interpreter.getInputTensor(0);
      final output = interpreter.getOutputTensor(0);
      final want = [1, meta.inputSize, meta.inputSize, 3];
      if (input.shape.length != 4 || !_same(input.shape, want)) {
        throw ModelContractException('model input is ${input.shape}, model_meta.json says $want');
      }
      final wantType = meta.inputType == ModelInputType.float32 ? TensorType.float32 : TensorType.uint8;
      if (input.type != wantType) {
        throw ModelContractException('model input type is ${input.type}, model_meta.json says ${meta.inputType.name}');
      }
      if (output.shape.length != 2 || output.shape[0] != 1 || output.shape[1] != meta.labelCount) {
        throw ModelContractException('model output is ${output.shape}, expected [1, ${meta.labelCount}]');
      }
      final q = output.params;
      return TfliteModelRunner._(interpreter, await IsolateInterpreter.create(address: interpreter.address), meta, output.type, q.scale, q.zeroPoint);
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<List<double>> run(Object input) async {
    final shaped = (input as List).reshape<Object>([1, _meta.inputSize, _meta.inputSize, 3]);
    final n = _meta.labelCount;
    if (_outputType == TensorType.float32) {
      final out = [List<double>.filled(n, 0)];
      await _isolate.run(shaped, out);
      return out[0];
    }
    // Quantised output: dequantise with the tensor's scale and zero point.
    final out = [List<int>.filled(n, 0)];
    await _isolate.run(shaped, out);
    return [for (final v in out[0]) (v - _zeroPoint) * _scale];
  }

  @override
  Future<void> close() async {
    await _isolate.close();
    _interpreter.close();
  }
}

