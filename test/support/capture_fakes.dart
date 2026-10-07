import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mather_sathi/features/capture/data/image_compressor.dart';
import 'package:mather_sathi/features/capture/data/image_prep_service.dart';
import 'package:mather_sathi/features/capture/data/pending_capture_store.dart';
import 'package:mather_sathi/features/capture/data/photo_picker.dart';
import 'package:mather_sathi/features/capture/domain/crop_selection.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';

/// Pure-Dart stand-in for the native compressor: decode, resize so the short side is [minSide], re-encode.
class FakeCompressor implements ImageCompressor {
  final calls = <(int quality, int side)>[];

  Uint8List _do(img.Image src, int quality, int minSide) {
    calls.add((quality, minSide));
    final short = src.width < src.height ? src.width : src.height;
    final scaled = short > minSide
        ? (src.width < src.height
            ? img.copyResize(src, width: minSide)
            : img.copyResize(src, height: minSide))
        : src;
    return Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
  }

  @override
  Future<Uint8List> fromFile(String path, {required int quality, required int minSide}) async =>
      _do(img.decodeImage(File(path).readAsBytesSync())!, quality, minSide);

  @override
  Future<Uint8List> fromBytes(Uint8List bytes, {required int quality, required int minSide}) async =>
      _do(img.decodeJpg(bytes)!, quality, minSide);
}

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.file, this.lost, this.throws = false});
  File? file;
  File? lost;
  bool throws;
  final picked = <PhotoSource>[];

  @override
  Future<File?> pick(PhotoSource source) async {
    picked.add(source);
    if (throws) throw Exception('camera unavailable');
    return file;
  }

  @override
  Future<File?> retrieveLost() async => lost;
}

class FakePendingStore implements PendingCaptureStore {
  CropSelection? value;
  final saves = <CropSelection>[];

  @override
  Future<void> save(CropSelection s) async {
    value = s;
    saves.add(s);
  }

  @override
  Future<CropSelection?> load() async => value;

  @override
  Future<void> clear() async => value = null;
}

/// Prep service with a canned result.
class FakePrepService extends ImagePrepService {
  FakePrepService(this.result, {this.throws = false})
      : super(FakeCompressor(), () => RemoteFlags.defaults);
  PreparedImage result;
  bool throws;
  int calls = 0;

  @override
  Future<PreparedImage> prepare(File src) async {
    calls++;
    if (throws) throw const ImagePrepException('boom');
    return result;
  }
}
