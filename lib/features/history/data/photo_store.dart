import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the prepared JPEG of a diagnosis lives. Only the prepared copy (<= 300 KB, no EXIF) is ever stored; originals never are.
abstract interface class PhotoStore {
  /// Writes [jpeg] and returns the stored path.
  Future<String> save(String id, Uint8List jpeg);

  /// Deletes files, ignoring ones that are already gone.
  Future<void> delete(Iterable<String> paths);
}

class FilePhotoStore implements PhotoStore {
  FilePhotoStore([Future<Directory> Function()? root]) : _root = root ?? _defaultRoot;
  final Future<Directory> Function() _root;

  static Future<Directory> _defaultRoot() async =>
      Directory(p.join((await getApplicationDocumentsDirectory()).path, 'photos'));

  @override
  Future<String> save(String id, Uint8List jpeg) async {
    final dir = await _root();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$id.jpg'));
    await file.writeAsBytes(jpeg, flush: true);
    return file.path;
  }

  @override
  Future<void> delete(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } on FileSystemException {
        // A leftover file is harmless; never fail a save because cleanup failed.
      }
    }
  }
}
