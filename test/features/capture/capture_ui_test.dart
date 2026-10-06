import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mather_sathi/features/capture/data/image_analysis.dart';
import 'package:mather_sathi/features/capture/data/image_prep_service.dart';
import 'package:mather_sathi/features/capture/data/photo_picker.dart';
import 'package:mather_sathi/features/capture/domain/crop_selection.dart';
import 'package:mather_sathi/features/capture/presentation/guidance_sheet.dart';
import 'package:mather_sathi/features/capture/providers/capture_provider.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';

import '../../support/capture_fakes.dart';
import '../../support/pump_app.dart';

final _stats = const ImageStats(meanLuma: 100, laplacianVar: 500);
final _jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

void main() {
  late FakePhotoPicker picker;
  late FakePendingStore pending;

  Future<FakePrepService> open(WidgetTester tester, PreparedImage result,
      {UserProfile saved = doneProfile}) async {
    picker = FakePhotoPicker(file: File('photo.jpg'));
    pending = FakePendingStore();
    final prep = FakePrepService(result);
    await pumpApp(tester, saved: saved, overrides: [
      photoPickerProvider.overrideWithValue(picker),
      pendingCaptureStoreProvider.overrideWithValue(pending),
      imagePrepServiceProvider.overrideWithValue(prep),
    ]);
    return prep;
  }

  testWidgets('home shows 8 crops plus "other" and remembers the last choice', (tester) async {
    await open(tester, PreparedImage.ready(_jpeg, _stats));
    for (final id in ['rice', 'jute', 'potato', 'tomato', 'brinjal', 'chili', 'onion', 'mustard', 'other']) {
      expect(find.byKey(Key('crop_$id')), findsOneWidget, reason: id);
    }
    expect(find.text('অন্যান্য ফসল'), findsOneWidget);
    await tester.tap(find.byKey(const Key('crop_tomato')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('crop_tomato')), matching: find.byIcon(Icons.check_circle)),
        findsOneWidget);
  });

  testWidgets('capture buttons are disabled until a crop is chosen', (tester) async {
    await open(tester, PreparedImage.ready(_jpeg, _stats),
        saved: const UserProfile(onboardingDone: true, district: 'dhaka', upazila: '1'));
    expect(tester.widget<FilledButton>(find.byKey(const Key('take_photo'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('crop_rice')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('take_photo'))).onPressed, isNotNull);
  });

  testWidgets('"other" dialog: OK needs text, accepts at most 40 characters', (tester) async {
    await open(tester, PreparedImage.ready(_jpeg, _stats));
    await tester.tap(find.byKey(const Key('crop_other')));
    await tester.pumpAndSettle();

    FilledButton ok() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ঠিক আছে'));
    expect(ok().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'a' * 60);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
        CropSelection.maxLabelLength);

    await tester.enterText(find.byType(TextField), 'ধনেপাতা');
    await tester.pump();
    expect(ok().onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'ঠিক আছে'));
    await tester.pumpAndSettle();
    expect(find.text('ধনেপাতা'), findsOneWidget);
  });

  testWidgets('camera: guidance sheet closes itself after 3 s, then the camera opens', (tester) async {
    await open(tester, PreparedImage.ready(_jpeg, _stats));
    await tester.tap(find.byKey(const Key('take_photo')));
    await tester.pumpAndSettle();
    expect(find.text('ঝাপসা ছবি দেবেন না'), findsOneWidget);
    expect(picker.picked, isEmpty);

    await tester.pump(kGuidanceDuration + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(picker.picked, [PhotoSource.camera]);
    expect(find.byKey(const Key('analyze')), findsOneWidget); // ready preview
  });

  testWidgets('guidance can be dismissed early with the button', (tester) async {
    await open(tester, PreparedImage.ready(_jpeg, _stats));
    await tester.tap(find.byKey(const Key('take_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ঠিক আছে'));
    await tester.pumpAndSettle();
    expect(picker.picked, [PhotoSource.camera]);
  });

  testWidgets('gallery skips the guidance sheet', (tester) async {
    await open(tester, PreparedImage.ready(_jpeg, _stats));
    await tester.tap(find.byKey(const Key('pick_gallery')));
    await tester.pumpAndSettle();
    expect(picker.picked, [PhotoSource.gallery]);
    expect(find.text('ঝাপসা ছবি দেবেন না'), findsNothing);
  });

  const tips = {
    ImageIssue.blurry: 'ছবিটি একটু ঝাপসা — আবার চেষ্টা করুন',
    ImageIssue.tooDark: 'আলো কম — আলোতে গিয়ে আবার ছবি তুলুন',
    ImageIssue.tooSmall: 'ছবির মান কম — আরও কাছ থেকে তুলুন',
    ImageIssue.notAPlant: 'এটি গাছের ছবি বলে মনে হচ্ছে না — রোগাক্রান্ত পাতা ফ্রেমে রাখুন',
    ImageIssue.wrongCrop: 'এটি ধান বলে মনে হচ্ছে না — ফসল ঠিক আছে?',
  };
  for (final e in tips.entries) {
    testWidgets('${e.key.name}: shows its own tip, and retake keeps the crop', (tester) async {
      await open(tester, PreparedImage.rejected(e.key));
      await tester.tap(find.byKey(const Key('pick_gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retake_tip')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('retake_tip'))).data, e.value);

      // Retake from the gallery button: same crop, picker called again.
      await tester.tap(find.byKey(const Key('retake_gallery')));
      await tester.pumpAndSettle();
      expect(picker.picked.length, 2);
      final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('retake_tip'))));
      expect(container.read(captureProvider).selection!.id, 'rice');
    });
  }

  testWidgets('leaving the preview clears the photo but keeps the crop', (tester) async {
    await open(tester, PreparedImage.ready(_jpeg, _stats));
    await tester.tap(find.byKey(const Key('pick_gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('take_photo'))));
    expect(container.read(captureProvider).prepared, isNull);
    expect(container.read(captureProvider).selection!.id, 'rice');
  });

  testWidgets('a photo recovered after the app was killed opens the preview', (tester) async {
    picker = FakePhotoPicker(lost: File('lost.jpg'));
    pending = FakePendingStore()..value = const CropSelection('jute');
    await pumpApp(tester, saved: doneProfile, overrides: [
      photoPickerProvider.overrideWithValue(picker),
      pendingCaptureStoreProvider.overrideWithValue(pending),
      imagePrepServiceProvider.overrideWithValue(FakePrepService(PreparedImage.ready(_jpeg, _stats))),
    ]);
    expect(find.byKey(const Key('analyze')), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('analyze'))));
    expect(container.read(captureProvider).selection!.id, 'jute');
  });
}
