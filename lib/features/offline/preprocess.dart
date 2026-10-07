import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'model_contract.dart';

const _imagenetMean = [0.485, 0.456, 0.406];
const _imagenetStd = [0.229, 0.224, 0.225];

typedef PreprocessArgs = ({Uint8List jpeg, int size, ModelInputType type, ResizeMode resize, Normalization norm});

typedef RgbaArgs = ({Uint8List rgba, int width, int height, int size, ModelInputType type, ResizeMode resize, Normalization norm});

/// JPEG → flat NHWC tensor data (RGB) for the model, exactly as the training pipeline preprocessed it:
/// resize to `size x size` (squashed, not cropped) with [ResizeMode], then [Normalization].
/// Returns a [Float32List] or a [Uint8List].
///
/// The JPEG is decoded by the platform codec (libjpeg-turbo, bit-identical to PIL/OpenCV), NOT by the pure-Dart
/// `image` package: that decoder upsamples chroma differently and differs from the training pixels by ~5/255 on average
/// (up to 77/255 on saturated edges), which would quietly cost offline accuracy. The decode is asynchronous and runs
/// off the UI thread; the resize and normalisation then run in a background isolate.
Future<Object> preprocessJpeg(PreprocessArgs a) async {
  final codec = await ui.instantiateImageCodec(a.jpeg);
  final ui.FrameInfo frame;
  try {
    frame = await codec.getNextFrame();
  } finally {
    codec.dispose();
  }
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final (w, h) = (image.width, image.height);
  image.dispose();
  if (data == null) throw const FormatException('could not decode the photo');
  return compute(
    preprocessRgba,
    (rgba: data.buffer.asUint8List(), width: w, height: h, size: a.size, type: a.type, resize: a.resize, norm: a.norm),
  );
}

/// Pure part of the pipeline: RGBA pixels in, model tensor data out. Top-level so `compute` can run it.
Object preprocessRgba(RgbaArgs a) {
  final rgb = Uint8List(a.width * a.height * 3);
  for (var i = 0, j = 0; i < a.rgba.length; i += 4) {
    rgb[j++] = a.rgba[i];
    rgb[j++] = a.rgba[i + 1];
    rgb[j++] = a.rgba[i + 2];
  }
  final pixels = a.resize == ResizeMode.area
      ? _resizeArea(rgb, a.width, a.height, a.size)
      : _resizeBilinear(rgb, a.width, a.height, a.size);

  if (a.type == ModelInputType.uint8) {
    return Uint8List.fromList([for (final v in pixels) v.round().clamp(0, 255)]);
  }
  final out = Float32List(pixels.length);
  for (var i = 0; i < pixels.length; i++) {
    final v = pixels[i];
    out[i] = switch (a.norm) {
      Normalization.zeroOne => v / 255.0,
      Normalization.minusOneOne => v / 127.5 - 1.0,
      Normalization.imagenet => (v / 255.0 - _imagenetMean[i % 3]) / _imagenetStd[i % 3],
      Normalization.none => v,
    };
  }
  return out;
}

/// Bilinear, half-pixel centres, no antialiasing: the TensorFlow / Keras default. Output is float, unrounded,
/// like `tf.image.resize` on a float image.
Float64List _resizeBilinear(Uint8List src, int w, int h, int size) {
  final out = Float64List(size * size * 3);
  final xs = List<(int, int, double)>.generate(size, (x) {
    final f = (x + 0.5) * w / size - 0.5;
    final x0 = f.floor();
    return (x0.clamp(0, w - 1), (x0 + 1).clamp(0, w - 1), (f - x0).clamp(0.0, 1.0));
  });
  var o = 0;
  for (var y = 0; y < size; y++) {
    final fy = (y + 0.5) * h / size - 0.5;
    final y0 = fy.floor();
    final r0 = y0.clamp(0, h - 1), r1 = (y0 + 1).clamp(0, h - 1);
    final wy = (fy - y0).clamp(0.0, 1.0);
    for (var x = 0; x < size; x++) {
      final (x0, x1, wx) = xs[x];
      for (var c = 0; c < 3; c++) {
        final top = src[(r0 * w + x0) * 3 + c] * (1 - wx) + src[(r0 * w + x1) * 3 + c] * wx;
        final bot = src[(r1 * w + x0) * 3 + c] * (1 - wx) + src[(r1 * w + x1) * 3 + c] * wx;
        out[o++] = top * (1 - wy) + bot * wy;
      }
    }
  }
  return out;
}

/// Area (box) averaging: each output pixel is the mean of the source region it covers, with fractional
/// edge weights. Equivalent to `cv2.INTER_AREA` / PIL `Image.BOX`. Output is float, unrounded.
Float64List _resizeArea(Uint8List src, int w, int h, int size) {
  final out = Float64List(size * size * 3);
  final sx = w / size, sy = h / size;
  var o = 0;
  for (var y = 0; y < size; y++) {
    final y0 = y * sy, y1 = (y + 1) * sy;
    for (var x = 0; x < size; x++) {
      final x0 = x * sx, x1 = (x + 1) * sx;
      final sum = [0.0, 0.0, 0.0];
      var weight = 0.0;
      for (var j = y0.floor(); j < y1.ceil() && j < h; j++) {
        final wy = (j + 1 < y1 ? j + 1 : y1) - (j > y0 ? j : y0);
        for (var i = x0.floor(); i < x1.ceil() && i < w; i++) {
          final wx = (i + 1 < x1 ? i + 1 : x1) - (i > x0 ? i : x0);
          final wt = wx * wy;
          weight += wt;
          for (var c = 0; c < 3; c++) {
            sum[c] += src[(j * w + i) * 3 + c] * wt;
          }
        }
      }
      for (var c = 0; c < 3; c++) {
        out[o++] = sum[c] / weight;
      }
    }
  }
  return out;
}
