import 'dart:convert';

/// One output class of the model: index in the output vector is the position in `labels.json`.
class ModelLabel {
  const ModelLabel({required this.diseaseId, required this.crop});
  final String diseaseId; // KB id | 'healthy' | 'unknown'
  final String crop;
}

class ModelContractException implements Exception {
  const ModelContractException(this.message);
  final String message;
  @override
  String toString() => 'ModelContractException: $message';
}

/// Parses `assets/models/labels.json`: `[{"disease_id": "...", "crop": "..."}, ...]`, in output order.
List<ModelLabel> parseLabels(String json) {
  try {
    final j = jsonDecode(json);
    if (j is! List || j.isEmpty) throw const ModelContractException('labels.json must be a non-empty array');
    return [
      for (final e in j)
        ModelLabel(
          diseaseId: (e as Map)['disease_id'] as String,
          crop: e['crop'] as String,
        ),
    ];
  } on ModelContractException {
    rethrow;
  } catch (e) {
    throw ModelContractException('labels.json is malformed: $e');
  }
}

enum ModelInputType { float32, uint8 }

/// How the photo is shrunk to the model's input size. Must match training exactly (docs/model-handoff.md):
/// resize methods differ by up to ~0.03 mean per pixel, enough to quietly cost accuracy.
enum ResizeMode {
  /// Area / box averaging: `cv2.INTER_AREA`, PIL `Image.BOX`.
  area,

  /// Bilinear with half-pixel centres and NO antialiasing: `tf.image.resize(method='bilinear', antialias=False)`,
  /// `tf.keras.layers.Resizing`.
  bilinear,
}

enum Normalization {
  /// value / 255
  zeroOne,

  /// value / 127.5 - 1
  minusOneOne,

  /// (value / 255 - mean) / std with the ImageNet constants
  imagenet,

  /// raw 0..255 (for a uint8-quantised input tensor)
  none,
}

String _modelFile(Object? v) {
  if (v is String && RegExp(r'^[A-Za-z0-9_.-]+\.tflite$').hasMatch(v)) return v;
  throw ModelContractException('file must be a plain *.tflite file name, got $v');
}

/// `assets/models/model_meta.json`: how the model was trained, so the app can preprocess identically.
/// Mismatched preprocessing silently ruins accuracy, so every field is explicit and validated (see docs/model-handoff.md).
class ModelMeta {
  const ModelMeta({
    required this.version,
    required this.file,
    required this.inputSize,
    required this.inputType,
    required this.resize,
    required this.normalization,
    required this.outputIsLogits,
    required this.labelCount,
  });

  final String version;

  /// The `.tflite` file name inside `assets/models/`.
  final String file;

  /// Square input side, e.g. 224. The photo is resized to `inputSize x inputSize` (squashed, not cropped).
  final int inputSize;
  final ModelInputType inputType;
  final ResizeMode resize;
  final Normalization normalization;

  /// True when the model outputs logits (softmax is applied in the app), false for probabilities.
  final bool outputIsLogits;
  final int labelCount;

  factory ModelMeta.parse(String json) {
    try {
      final j = jsonDecode(json) as Map<String, dynamic>;
      final type = switch (j['input_type']) {
        'float32' => ModelInputType.float32,
        'uint8' => ModelInputType.uint8,
        final v => throw ModelContractException('input_type must be float32 or uint8, got $v'),
      };
      final resize = switch (j['resize']) {
        'area' => ResizeMode.area,
        'bilinear' => ResizeMode.bilinear,
        final v => throw ModelContractException('resize must be area or bilinear, got $v'),
      };
      final norm = switch (j['normalization']) {
        'zero_one' => Normalization.zeroOne,
        'minus_one_one' => Normalization.minusOneOne,
        'imagenet' => Normalization.imagenet,
        'none' => Normalization.none,
        final v => throw ModelContractException('unknown normalization $v'),
      };
      if (type == ModelInputType.uint8 && norm != Normalization.none) {
        throw const ModelContractException('a uint8 input needs normalization "none"');
      }
      if (type == ModelInputType.float32 && norm == Normalization.none) {
        throw const ModelContractException('a float32 input needs a normalization');
      }
      final output = switch (j['output']) {
        'probabilities' => false,
        'logits' => true,
        final v => throw ModelContractException('output must be probabilities or logits, got $v'),
      };
      final size = j['input_size'];
      final labels = j['labels'];
      if (size is! int || size < 32 || size > 1024) throw const ModelContractException('input_size must be an int in 32..1024');
      if (labels is! int || labels < 2) throw const ModelContractException('labels must be an int >= 2');
      return ModelMeta(
        version: j['version'] as String,
        file: _modelFile(j['file']),
        inputSize: size,
        inputType: type,
        resize: resize,
        normalization: norm,
        outputIsLogits: output,
        labelCount: labels,
      );
    } on ModelContractException {
      rethrow;
    } catch (e) {
      throw ModelContractException('model_meta.json is malformed: $e');
    }
  }
}
