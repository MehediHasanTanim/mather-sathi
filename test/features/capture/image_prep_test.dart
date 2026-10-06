import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/capture/data/image_analysis.dart';
import 'package:mather_sathi/features/capture/data/image_prep_service.dart';
import 'package:mather_sathi/features/capture/data/jpeg_utils.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';

import '../../support/capture_fakes.dart';
import '../../support/fixtures.dart';

void main() {
  late Directory dir;
  late FakeCompressor compressor;
  late ImagePrepService service;

  setUpAll(() => dir = Directory.systemTemp.createTempSync('prep_test'));
  tearDownAll(() => dir.deleteSync(recursive: true));
  setUp(() {
    compressor = FakeCompressor();
    service = ImagePrepService(compressor, () => RemoteFlags.defaults);
  });

  group('jpeg utils', () {
    test('jpegSize reads dimensions without decoding', () {
      final b = jpegBytes(sharpImage(1, w: 640, h: 480));
      expect(jpegSize(b), (width: 640, height: 480));
      expect(jpegSize(withExif(b)), (width: 640, height: 480));
    });

    test('jpegSize is null for non-JPEG and truncated data', () {
      expect(jpegSize(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
      expect(jpegSize(jpegBytes(sharpImage(1)).sublist(0, 12)), isNull);
    });

    test('stripMetadata removes EXIF and leaves a decodable image', () {
      final clean = jpegBytes(sharpImage(2, w: 600, h: 500));
      final dirty = withExif(clean);
      expect(hasMetadata(dirty), isTrue);
      final stripped = stripMetadata(dirty);
      expect(hasMetadata(stripped), isFalse);
      expect(stripped, clean);
      expect(img.decodeJpg(stripped)!.width, 600);
    });

    test('stripMetadata leaves clean and non-JPEG data untouched', () {
      final clean = jpegBytes(sharpImage(3, w: 600, h: 500));
      expect(identical(stripMetadata(clean), clean), isTrue);
      final junk = Uint8List.fromList([9, 9, 9, 9]);
      expect(identical(stripMetadata(junk), junk), isTrue);
    });
  });

  group('ImagePrepService', () {
    test('a sharp, well lit photo is ready: small, upright size, no EXIF', () async {
      final f = writeJpeg(dir, 'sharp.jpg', sharpImage(10));
      final out = await service.prepare(f);
      expect(out.isReady, isTrue, reason: '${out.stats}');
      expect(out.jpeg!.length, lessThanOrEqualTo(service.maxBytes));
      expect(hasMetadata(out.jpeg!), isFalse);
      final size = jpegSize(out.jpeg!)!;
      expect(size.width < size.height ? size.width : size.height, lessThanOrEqualTo(1024));
    });

    test('EXIF in the compressor output is removed anyway', () async {
      final f = writeJpeg(dir, 'sharp2.jpg', sharpImage(11));
      final svc = ImagePrepService(_ExifCompressor(compressor), () => RemoteFlags.defaults);
      final out = await svc.prepare(f);
      expect(out.isReady, isTrue);
      expect(hasMetadata(out.jpeg!), isFalse);
    });

    test('a blurry photo asks for a retake', () async {
      final out = await service.prepare(writeJpeg(dir, 'blur.jpg', blurryImage(12)));
      expect(out.issue, ImageIssue.blurry, reason: '${out.stats}');
      expect(out.jpeg, isNull);
    });

    test('a dark photo asks for a retake', () async {
      final out = await service.prepare(writeJpeg(dir, 'dark.jpg', darkImage(13)));
      expect(out.issue, ImageIssue.tooDark, reason: '${out.stats}');
    });

    test('a photo below 480 px is rejected before any compression', () async {
      final f = writeJpeg(dir, 'small.jpg', sharpImage(14, w: 400, h: 300));
      final out = await service.prepare(f);
      expect(out.issue, ImageIssue.tooSmall);
      expect(compressor.calls, isEmpty);
    });

    test('size loop steps quality then dimensions until the limit is met', () async {
      final f = writeJpeg(dir, 'big.jpg', sharpImage(15));
      final tiny = ImagePrepService(compressor, () => RemoteFlags.defaults, maxBytes: 1);
      await tiny.prepare(f); // never fits: tries every attempt
      expect(compressor.calls.take(5).toList(), ImagePrepService.attempts);
      expect(compressor.calls.length, 6); // 5 attempts + thumbnail
    });

    test('thresholds come from RemoteFlags', () async {
      final f = writeJpeg(dir, 'blur2.jpg', blurryImage(16));
      final lenient = ImagePrepService(
          compressor, () => RemoteFlags.fromValues({'blur_threshold': 0, 'dark_threshold': 0}));
      expect((await lenient.prepare(f)).isReady, isTrue);
    });
  });

  test('detection rates on the synthetic set: >= 90% caught, <= 10% false rejects', () async {
    var caughtBlur = 0, caughtDark = 0, falseRejects = 0;
    const n = 10;
    for (var s = 100; s < 100 + n; s++) {
      if ((await service.prepare(writeJpeg(dir, 'b$s.jpg', blurryImage(s)))).issue ==
          ImageIssue.blurry) {
        caughtBlur++;
      }
      if ((await service.prepare(writeJpeg(dir, 'd$s.jpg', darkImage(s)))).issue ==
          ImageIssue.tooDark) {
        caughtDark++;
      }
      if (!(await service.prepare(writeJpeg(dir, 'g$s.jpg', sharpImage(s)))).isReady) {
        falseRejects++;
      }
    }
    expect(caughtBlur / n, greaterThanOrEqualTo(0.9));
    expect(caughtDark / n, greaterThanOrEqualTo(0.9));
    expect(falseRejects / n, lessThanOrEqualTo(0.1));
  });

  test('analyzeThumbnail reports luminance and edge variance', () {
    final s = analyzeThumbnail(jpegBytes(img.Image(width: 64, height: 64)..clear(img.ColorRgb8(200, 200, 200))));
    expect(s.meanLuma, closeTo(200, 3));
    expect(s.laplacianVar, lessThan(1));
    expect(() => analyzeThumbnail(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });
}

class _ExifCompressor extends FakeCompressor {
  _ExifCompressor(this._inner);
  final FakeCompressor _inner;

  @override
  Future<Uint8List> fromFile(String path, {required int quality, required int minSide}) async =>
      withExif(await _inner.fromFile(path, quality: quality, minSide: minSide));
}
