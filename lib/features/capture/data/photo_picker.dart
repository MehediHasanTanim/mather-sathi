import 'dart:io';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

abstract interface class PhotoPicker {
  /// Null when the user cancels.
  Future<File?> pick(PhotoSource source);

  /// Android may kill the app while the system camera is open; this returns the photo taken, if any.
  Future<File?> retrieveLost();
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<File?> pick(PhotoSource source) async {
    final x = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      requestFullMetadata: false, // we never read location; avoids the media-location permission
    );
    return x == null ? null : File(x.path);
  }

  @override
  Future<File?> retrieveLost() async {
    final r = await _picker.retrieveLostData();
    if (r.isEmpty || r.file == null) return null;
    return File(r.file!.path);
  }
}
