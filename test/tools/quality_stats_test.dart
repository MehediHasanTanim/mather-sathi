// Not a test: a measuring tool for task 9.1, run through `flutter test` because it needs the platform image codec.
// Skipped unless QUALITY_DIR is set. Layout: QUALITY_DIR/{blur,dark}/{good,bad}/*.jpg
//   QUALITY_DIR=/data/quality QUALITY_OUT=reports/quality.json flutter test test/tools/quality_stats_test.dart
// Prints the values the app's gates compare with `blur_threshold` (Laplacian variance) and `dark_threshold` (mean luma),
// in the shape tools/eval/calibrate.ts expects. The thumbnail is made with the `image` package, not the phone's native
// compressor, so confirm the final numbers on a real device with a few photos.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mather_sathi/features/capture/data/image_analysis.dart';

void main() {
  final dir = Platform.environment['QUALITY_DIR'];
  test('measure photo-quality stats', () {
    final out = <String, Map<String, List<double>>>{};
    for (final gate in ['blur', 'dark']) {
      for (final kind in ['good', 'bad']) {
        final d = Directory('$dir/$gate/$kind');
        final values = <double>[];
        if (d.existsSync()) {
          for (final f in d.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.jpg'))) {
            final decoded = img.decodeJpg(f.readAsBytesSync());
            if (decoded == null) continue;
            final thumb = img.copyResize(decoded, width: decoded.width < decoded.height ? 256 : null, height: decoded.width < decoded.height ? null : 256, interpolation: img.Interpolation.average);
            final stats = analyzeThumbnail(Uint8List.fromList(img.encodeJpg(thumb, quality: 70)));
            values.add(gate == 'blur' ? stats.laplacianVar : stats.meanLuma);
          }
        }
        (out[gate] ??= {})[kind] = values;
      }
    }
    final json = const JsonEncoder.withIndent('  ').convert(out);
    final path = Platform.environment['QUALITY_OUT'];
    if (path != null) File(path).writeAsStringSync(json);
    // ignore: avoid_print
    print(json);
  }, skip: dir == null ? 'set QUALITY_DIR to run' : false);
}
