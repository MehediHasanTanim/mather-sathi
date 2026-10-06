import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/flags/remote_flags.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/image_compressor.dart';
import '../data/image_prep_service.dart';
import '../data/pending_capture_store.dart';
import '../data/photo_picker.dart';
import '../domain/crop_selection.dart';

final photoPickerProvider = Provider<PhotoPicker>((ref) => ImagePickerPhotoPicker());
final imageCompressorProvider =
    Provider<ImageCompressor>((ref) => const NativeImageCompressor());
final pendingCaptureStoreProvider =
    Provider<PendingCaptureStore>((ref) => PrefsPendingCaptureStore());

final imagePrepServiceProvider = Provider<ImagePrepService>((ref) => ImagePrepService(
      ref.watch(imageCompressorProvider),
      () => ref.read(remoteFlagsProvider), // read at prepare time: thresholds can change remotely
    ));

enum CaptureStatus { idle, preparing, ready, retake, failed }

@immutable
class CaptureState {
  const CaptureState({this.selection, this.status = CaptureStatus.idle, this.prepared});
  final CropSelection? selection;
  final CaptureStatus status;
  final PreparedImage? prepared;

  CaptureState copyWith({CaptureStatus? status, PreparedImage? prepared, CropSelection? selection,
          bool clearPrepared = false}) =>
      CaptureState(
        selection: selection ?? this.selection,
        status: status ?? this.status,
        prepared: clearPrepared ? null : (prepared ?? this.prepared),
      );
}

final captureProvider =
    NotifierProvider<CaptureNotifier, CaptureState>(CaptureNotifier.new);

class CaptureNotifier extends Notifier<CaptureState> {
  @override
  CaptureState build() {
    // If the profile finishes loading after this provider was created, adopt its default crop
    // once (only while nothing is selected), without resetting an in-progress capture.
    ref.listen(profileProvider, (_, next) {
      final crop = next.value?.defaultCrop;
      if (crop != null && state.selection == null) {
        state = state.copyWith(selection: CropSelection(crop));
      }
    });
    final crop = ref.read(profileProvider).value?.defaultCrop;
    return CaptureState(selection: crop == null ? null : CropSelection(crop));
  }

  /// Picks a launch crop and remembers it as the profile default.
  Future<void> selectCrop(String id) async {
    state = state.copyWith(selection: CropSelection(id));
    await ref.read(profileProvider.notifier).change((p) => p.copyWith(defaultCrop: id));
  }

  /// "Other crop": free text, 1-40 characters. Not remembered across sessions.
  void selectOther(String label) {
    if (!CropSelection.isValidLabel(label)) return;
    state = state.copyWith(selection: CropSelection.other(label));
  }

  /// Opens the picker. Returns null if cancelled or if no crop is selected.
  /// A picker error moves the state to [CaptureStatus.failed].
  Future<File?> pick(PhotoSource source) async {
    final selection = state.selection;
    if (selection == null) return null;
    final store = ref.read(pendingCaptureStoreProvider);
    try {
      if (source == PhotoSource.camera) await store.save(selection);
      return await ref.read(photoPickerProvider).pick(source);
    } catch (e) {
      debugPrint('photo pick failed: $e');
      state = state.copyWith(status: CaptureStatus.failed, clearPrepared: true);
      return null;
    } finally {
      await store.clear();
    }
  }

  /// On startup: returns a photo captured just before Android killed the app, and restores its crop.
  Future<File?> recoverLostPhoto() async {
    try {
      final file = await ref.read(photoPickerProvider).retrieveLost();
      final pending = await ref.read(pendingCaptureStoreProvider).load();
      await ref.read(pendingCaptureStoreProvider).clear();
      if (file == null) return null;
      final selection = pending ?? state.selection;
      if (selection == null) return null;
      state = state.copyWith(selection: selection);
      return file;
    } catch (e) {
      debugPrint('lost photo recovery failed: $e');
      return null;
    }
  }

  Future<void> prepare(File photo) async {
    if (state.status == CaptureStatus.preparing) return; // ignore double taps
    state = state.copyWith(status: CaptureStatus.preparing, clearPrepared: true);
    try {
      final prepared = await ref.read(imagePrepServiceProvider).prepare(photo);
      state = state.copyWith(
        status: prepared.isReady ? CaptureStatus.ready : CaptureStatus.retake,
        prepared: prepared,
      );
    } catch (e) {
      debugPrint('image prep failed: $e');
      state = state.copyWith(status: CaptureStatus.failed, clearPrepared: true);
    }
  }

  /// Clears the photo but keeps the selected crop.
  void reset() => state = CaptureState(selection: state.selection);
}
