import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageStats {
  const ImageStats({required this.meanLuma, required this.laplacianVar});

  /// Mean luminance, 0 (black) to 255 (white).
  final double meanLuma;

  /// Variance of the 3x3 Laplacian response: low means few edges (blurry).
  final double laplacianVar;

  @override
  String toString() => 'ImageStats(meanLuma: ${meanLuma.toStringAsFixed(1)}, '
      'laplacianVar: ${laplacianVar.toStringAsFixed(1)})';
}

const kAnalysisWidth = 256;

/// Runs in an isolate via `compute`. [thumbnailJpeg] should already be small
/// (about 256 px); it is shrunk to [kAnalysisWidth] wide if larger.
ImageStats analyzeThumbnail(Uint8List thumbnailJpeg) {
  img.Image? image;
  try {
    image = img.decodeJpg(thumbnailJpeg);
  } on img.ImageException catch (e) {
    throw FormatException('thumbnail is not a decodable JPEG: ${e.message}');
  }
  if (image == null) throw const FormatException('thumbnail is not a decodable JPEG');
  if (image.width > kAnalysisWidth) image = img.copyResize(image, width: kAnalysisWidth);

  final w = image.width, h = image.height;
  final lum = Float32List(w * h);
  var sum = 0.0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final l = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      lum[y * w + x] = l;
      sum += l;
    }
  }
  final mean = sum / lum.length;

  // 3x3 Laplacian [0 1 0; 1 -4 1; 0 1 0]; variance of the response.
  var s = 0.0, s2 = 0.0;
  var n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final v = lum[(y - 1) * w + x] + lum[(y + 1) * w + x] +
          lum[y * w + x - 1] + lum[y * w + x + 1] - 4 * lum[y * w + x];
      s += v;
      s2 += v * v;
      n++;
    }
  }
  final variance = n == 0 ? 0.0 : s2 / n - (s / n) * (s / n);
  return ImageStats(meanLuma: mean, laplacianVar: variance);
}
