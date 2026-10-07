import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImagePrepException implements Exception {
  const ImagePrepException(this.message);
  final String message;
  @override
  String toString() => 'ImagePrepException: $message';
}

/// Native resize + JPEG encode. Orientation is corrected before metadata is dropped.
/// [minSide] is a lower bound on the scaled short side (plugin `minWidth/minHeight` semantics).
abstract interface class ImageCompressor {
  Future<Uint8List> fromFile(String path, {required int quality, required int minSide});
  Future<Uint8List> fromBytes(Uint8List bytes, {required int quality, required int minSide});
}

class NativeImageCompressor implements ImageCompressor {
  const NativeImageCompressor();

  @override
  Future<Uint8List> fromFile(String path, {required int quality, required int minSide}) async {
    final out = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: minSide,
      minHeight: minSide,
      quality: quality,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
      keepExif: false,
    );
    if (out == null || out.isEmpty) throw const ImagePrepException('compression failed');
    return out;
  }

  @override
  Future<Uint8List> fromBytes(Uint8List bytes, {required int quality, required int minSide}) async {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: minSide,
      minHeight: minSide,
      quality: quality,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
      keepExif: false,
    );
    if (out.isEmpty) throw const ImagePrepException('compression failed');
    return out;
  }
}
