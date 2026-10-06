import 'package:shared_preferences/shared_preferences.dart';

import '../domain/crop_selection.dart';

/// Remembers the crop chosen before the system camera opens, so a photo
/// recovered after the process was killed is paired with the right crop.
abstract interface class PendingCaptureStore {
  Future<void> save(CropSelection s);
  Future<CropSelection?> load();
  Future<void> clear();
}

class PrefsPendingCaptureStore implements PendingCaptureStore {
  static const _kId = 'pending_capture_crop';
  static const _kLabel = 'pending_capture_label';

  @override
  Future<void> save(CropSelection s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kId, s.id);
    if (s.label == null) {
      await p.remove(_kLabel);
    } else {
      await p.setString(_kLabel, s.label!);
    }
  }

  @override
  Future<CropSelection?> load() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_kId);
    return id == null ? null : CropSelection(id, label: p.getString(_kLabel));
  }

  @override
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kId);
    await p.remove(_kLabel);
  }
}
