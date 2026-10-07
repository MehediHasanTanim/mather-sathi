import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/capture/data/image_prep_service.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';

import '../../support/capture_fakes.dart';

List<File> _photos(String folder) {
  final d = Directory('test/fixtures/photos/$folder');
  if (!d.existsSync()) return const [];
  return d
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(f.path))
      .toList();
}

void main() {
  final sharp = _photos('sharp');
  final blurry = _photos('blurry');
  final dark = _photos('dark');
  final total = sharp.length + blurry.length + dark.length;

  test('real-photo detection rates', () async {
    final service = ImagePrepService(FakeCompressor(), () => RemoteFlags.defaults);

    Future<double> rate(List<File> files, bool Function(PreparedImage) hit, String label) async {
      var n = 0;
      for (final f in files) {
        final out = await service.prepare(f);
        if (hit(out)) n++;
        // ignore: avoid_print
        print('$label ${f.path.split('/').last}: ${out.issue.name} ${out.stats}');
      }
      return files.isEmpty ? 1 : n / files.length;
    }

    final caughtBlur = await rate(blurry, (o) => o.issue == ImageIssue.blurry, 'blurry');
    final caughtDark = await rate(dark, (o) => o.issue == ImageIssue.tooDark, 'dark');
    final accepted = await rate(sharp, (o) => o.isReady, 'sharp');

    expect(caughtBlur, greaterThanOrEqualTo(0.9));
    expect(caughtDark, greaterThanOrEqualTo(0.9));
    expect(1 - accepted, lessThanOrEqualTo(0.1));
  }, skip: total == 0 ? 'no real photos in test/fixtures/photos yet (see README there)' : false);
}
