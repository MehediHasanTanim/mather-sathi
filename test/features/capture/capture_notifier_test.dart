import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/features/capture/data/image_analysis.dart';
import 'package:mather_sathi/features/capture/data/image_prep_service.dart';
import 'package:mather_sathi/features/capture/data/photo_picker.dart';
import 'package:mather_sathi/features/capture/domain/crop_selection.dart';
import 'package:mather_sathi/features/capture/providers/capture_provider.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/features/profile/providers/profile_provider.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../../support/capture_fakes.dart';
import '../../support/fakes.dart';

final _photo = File('photo.jpg');

void main() {
  late FakeProfileStore profile;
  late FakePhotoPicker picker;
  late FakePendingStore pending;
  late FakePrepService prep;

  ProviderContainer make({UserProfile? saved, PreparedImage? result}) {
    profile = FakeProfileStore(saved);
    picker = FakePhotoPicker(file: _photo);
    pending = FakePendingStore();
    prep = FakePrepService(result ?? PreparedImage.ready(Uint8List(3), const ImageStats(meanLuma: 100, laplacianVar: 500)));
    final c = ProviderContainer(overrides: [
      profileStoreProvider.overrideWithValue(profile),
      photoPickerProvider.overrideWithValue(picker),
      pendingCaptureStoreProvider.overrideWithValue(pending),
      imagePrepServiceProvider.overrideWithValue(prep),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<ProviderContainer> ready({UserProfile? saved, PreparedImage? result}) async {
    final c = make(saved: saved, result: result);
    await c.read(profileProvider.future);
    return c;
  }

  group('crop selection', () {
    test('starts from the profile default crop', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'potato'));
      expect(c.read(captureProvider).selection, const CropSelection('potato'));
    });

    test('no default crop means nothing selected and capture is a no-op', () async {
      final c = await ready();
      expect(c.read(captureProvider).selection, isNull);
      expect(await c.read(captureProvider.notifier).pick(PhotoSource.camera), isNull);
      expect(picker.picked, isEmpty);
    });

    test('the last crop is remembered in the profile', () async {
      final c = await ready();
      await c.read(captureProvider.notifier).selectCrop('mustard');
      expect(profile.saved!.defaultCrop, 'mustard');
      expect(c.read(captureProvider).selection!.id, 'mustard');
    });

    test('"other" needs a non-empty label of at most 40 characters', () async {
      final c = await ready();
      final n = c.read(captureProvider.notifier);
      n.selectOther('   ');
      expect(c.read(captureProvider).selection, isNull);
      n.selectOther('a' * 41);
      expect(c.read(captureProvider).selection, isNull);
      n.selectOther('a' * 40);
      expect(c.read(captureProvider).selection!.isOther, isTrue);
      n.selectOther(' ধনেপাতা ');
      expect(c.read(captureProvider).selection!.param, 'other:ধনেপাতা');
      expect(profile.saved, isNull, reason: 'other crops are not persisted as the default');
    });

    test('label length counts characters, not UTF-16 units', () {
      expect(CropSelection.isValidLabel('ক' * 40), isTrue);
      expect(CropSelection.isValidLabel('ক' * 41), isFalse);
      expect(CropSelection.isValidLabel(null), isFalse);
    });
  });

  group('capture flow', () {
    test('cancel leaves the state untouched', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'rice'));
      picker.file = null;
      expect(await c.read(captureProvider.notifier).pick(PhotoSource.gallery), isNull);
      expect(c.read(captureProvider).status, CaptureStatus.idle);
    });

    test('camera pick stores the pending crop, then clears it', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'rice'));
      await c.read(captureProvider.notifier).pick(PhotoSource.camera);
      expect(pending.saves.single.id, 'rice');
      expect(pending.value, isNull);
    });

    test('picker failure moves to failed', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'rice'));
      picker.throws = true;
      expect(await c.read(captureProvider.notifier).pick(PhotoSource.camera), isNull);
      expect(c.read(captureProvider).status, CaptureStatus.failed);
    });

    test('prepare: ready, retake and failed outcomes', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'rice'));
      final n = c.read(captureProvider.notifier);
      await n.prepare(_photo);
      expect(c.read(captureProvider).status, CaptureStatus.ready);

      prep.result = const PreparedImage.rejected(ImageIssue.blurry);
      await n.prepare(_photo);
      expect(c.read(captureProvider).status, CaptureStatus.retake);
      expect(c.read(captureProvider).prepared!.issue, ImageIssue.blurry);

      prep.throws = true;
      await n.prepare(_photo);
      expect(c.read(captureProvider).status, CaptureStatus.failed);
    });

    test('a second prepare while one is running is ignored', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'rice'));
      final n = c.read(captureProvider.notifier);
      final first = n.prepare(_photo);
      await n.prepare(_photo);
      await first;
      expect(prep.calls, 1);
    });

    test('retake (reset) keeps the selected crop', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'rice'));
      final n = c.read(captureProvider.notifier);
      await n.prepare(_photo);
      n.reset();
      expect(c.read(captureProvider).status, CaptureStatus.idle);
      expect(c.read(captureProvider).prepared, isNull);
      expect(c.read(captureProvider).selection!.id, 'rice');
    });
  });

  group('lost data recovery', () {
    test('a photo taken before the app was killed comes back with its crop', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'rice'));
      picker.lost = _photo;
      pending.value = CropSelection.other('ধনেপাতা');
      final f = await c.read(captureProvider.notifier).recoverLostPhoto();
      expect(f, _photo);
      expect(c.read(captureProvider).selection!.label, 'ধনেপাতা');
      expect(pending.value, isNull);
    });

    test('nothing lost: returns null and clears the stale pending crop', () async {
      final c = await ready(saved: const UserProfile(defaultCrop: 'rice'));
      pending.value = const CropSelection('rice');
      expect(await c.read(captureProvider.notifier).recoverLostPhoto(), isNull);
      expect(pending.value, isNull);
    });
  });
}
