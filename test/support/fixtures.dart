import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Synthetic leaf-like texture: green gradient, random blobs and fine noise.
/// Validates the analysis logic only; real field photos are needed to tune thresholds (task 2.6 / 9.1).
img.Image sharpImage(int seed, {int w = 800, int h = 600}) {
  final r = Random(seed);
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final g = 90 + (80 * y / h).round();
      final n = r.nextInt(30) - 15;
      im.setPixelRgb(x, y, 40 + n, g + n, 30 + n);
    }
  }
  for (var i = 0; i < 70; i++) {
    img.fillCircle(im,
        x: r.nextInt(w), y: r.nextInt(h), radius: 8 + r.nextInt(40),
        color: img.ColorRgb8(r.nextInt(256), r.nextInt(256), r.nextInt(256)));
  }
  return im;
}

img.Image blurryImage(int seed) => img.gaussianBlur(sharpImage(seed), radius: 14);

img.Image darkImage(int seed) {
  final im = sharpImage(seed);
  return img.adjustColor(im, brightness: 0.12);
}

Uint8List jpegBytes(img.Image im, {int quality = 92}) =>
    Uint8List.fromList(img.encodeJpg(im, quality: quality));

File writeJpeg(Directory dir, String name, img.Image im) =>
    File('${dir.path}/$name')..writeAsBytesSync(jpegBytes(im));

/// Inserts an APP1 "Exif" segment (fake GPS payload) right after SOI.
Uint8List withExif(Uint8List jpeg) {
  final payload = [...'Exif\x00\x00'.codeUnits, ...List.filled(40, 0x47)];
  final len = payload.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE1, len >> 8, len & 0xFF, ...payload, ...jpeg.sublist(2),
  ]);
}
