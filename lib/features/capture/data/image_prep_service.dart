import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/flags/remote_flags.dart';
import '../../diagnosis/domain/image_issue.dart';
import 'image_analysis.dart';
import 'image_compressor.dart';
import 'jpeg_utils.dart';

class PreparedImage {
  const PreparedImage.ready(Uint8List this.jpeg, ImageStats this.stats) : issue = ImageIssue.none;
  const PreparedImage.rejected(this.issue, {this.stats}) : jpeg = null;

  /// Compressed, EXIF-free JPEG (about 300 KB or less). Null when rejected.
  final Uint8List? jpeg;
  final ImageIssue issue;
  final ImageStats? stats;

  bool get isReady => issue == ImageIssue.none;
}

/// Photo → small, clean JPEG, or a specific reason to retake (Design §6.1).
/// Heavy lifting is native; Dart only analyses a tiny thumbnail, in an isolate.
class ImagePrepService {
  ImagePrepService(this._compressor, this._flags, {this.maxBytes = 300 * 1024});

  final ImageCompressor _compressor;
  final RemoteFlags Function() _flags;
  final int maxBytes;

  static const minSourceSide = 480; // spec 1.3: minimum resolution 480x480
  static const _headBytes = 128 * 1024;
  static const _thumbSide = 256;

  /// (quality, short side) attempts, stopping at the first result within [maxBytes].
  static const attempts = [(80, 1024), (70, 1024), (60, 1024), (60, 896), (60, 768)];

  Future<PreparedImage> prepare(File src) async {
    final head = await _readHead(src);
    final size = jpegSize(head);
    if (size != null && (size.width < minSourceSide || size.height < minSourceSide)) {
      return const PreparedImage.rejected(ImageIssue.tooSmall);
    }

    Uint8List? bytes;
    for (final (quality, side) in attempts) {
      bytes = await _compressor.fromFile(src.path, quality: quality, minSide: side);
      if (bytes.length <= maxBytes) break;
    }
    final jpeg = stripMetadata(bytes!);

    final thumb = await _compressor.fromBytes(jpeg, quality: 70, minSide: _thumbSide);
    final ImageStats stats;
    try {
      stats = await compute(analyzeThumbnail, thumb);
    } on FormatException catch (e) {
      throw ImagePrepException(e.message);
    }

    final f = _flags();
    if (stats.meanLuma < f.darkThreshold) {
      return PreparedImage.rejected(ImageIssue.tooDark, stats: stats);
    }
    if (stats.laplacianVar < f.blurThreshold) {
      return PreparedImage.rejected(ImageIssue.blurry, stats: stats);
    }
    return PreparedImage.ready(jpeg, stats);
  }

  Future<Uint8List> _readHead(File f) async {
    final raf = await f.open();
    try {
      return await raf.read(_headBytes);
    } finally {
      await raf.close();
    }
  }
}
