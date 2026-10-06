import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/app.dart';
import 'package:mather_sathi/core/router/app_router.dart';
import 'package:mather_sathi/features/geo/data/districts_repository.dart';
import 'package:mather_sathi/features/onboarding/providers/onboarding_draft.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../support/fakes.dart';

Future<FakeProfileStore> pumpApp(WidgetTester tester, {UserProfile? saved}) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final store = FakeProfileStore(saved);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileStoreProvider.overrideWithValue(store),
      // Read the real file synchronously: rootBundle I/O does not settle under pumpAndSettle.
      districtsProvider.overrideWith((_) =>
          parseDistricts(File('assets/data/districts.json').readAsStringSync())),
    ],
    child: const KrishiApp(),
  ));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('onboardingRedirect', () {
    test('fresh install goes to onboarding', () => expect(
        onboardingRedirect(onboardingDone: false, location: '/'), '/onboarding'));
    test('done user leaves onboarding', () => expect(
        onboardingRedirect(onboardingDone: true, location: '/onboarding'), '/'));
    test('done user stays put', () => expect(
        onboardingRedirect(onboardingDone: true, location: '/history'), isNull));
    test('no redirect while the profile is loading', () => expect(
        onboardingRedirect(onboardingDone: null, location: '/'), isNull));
  });

  group('OnboardingDraft', () {
    test('selecting a different district clears the stale upazila', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(onboardingDraftProvider.notifier);
      c.listen(onboardingDraftProvider, (_, _) {}); // keep autoDispose alive
      n.selectDistrict('dhaka');
      n.selectUpazila('42');
      n.selectDistrict('dhaka');
      expect(c.read(onboardingDraftProvider).upazilaId, '42');
      n.selectDistrict('khulna');
      expect(c.read(onboardingDraftProvider).upazilaId, isNull);
    });

    test('defaults: reports on, backup off, contribution off', () {
      const d = OnboardingDraft();
      expect([d.shareReports, d.photoBackup, d.photoContribute], [true, false, false]);
    });
  });

  testWidgets('fresh install lands on onboarding and completes it offline', (tester) async {
    final store = await pumpApp(tester);

    // Slide 1 is shown; the shell is not.
    expect(find.text('স্বাগতম! ফসলের রোগ এখন ঘরে বসেই শনাক্ত করুন'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('পরবর্তী'));
      await tester.pumpAndSettle();
    }
    // Setup page: "Next" is disabled until district, upazila and crop are chosen.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.tap(find.byKey(const Key('pick_district')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ঢাকা');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ঢাকা').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick_upazila')));
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile))
        .first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('crop_rice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('পরবর্তী'));
    await tester.pumpAndSettle();

    // Consent: defaults and the non-toggle AI disclosure.
    expect(find.byKey(const Key('ai_disclosure')), findsOneWidget);
    bool on(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key(key))).value;
    expect(on('consent_reports'), isTrue);
    expect(on('consent_backup'), isFalse);
    expect(on('consent_contribute'), isFalse);

    await tester.tap(find.text('শুরু করুন'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(store.saved!.onboardingDone, isTrue);
    expect(store.saved!.defaultCrop, 'rice');
    expect(store.saved!.district, 'dhaka');
    expect(store.saved!.upazila, isNotNull);
    expect(store.saved!.photoBackup, isFalse);
  });

  testWidgets('relaunch with onboarding done skips onboarding; 4 tabs work', (tester) async {
    await pumpApp(tester,
        saved: const UserProfile(district: 'dhaka', upazila: '1', defaultCrop: 'rice', onboardingDone: true));

    expect(find.text('ছবি তুলে রোগ শনাক্ত করুন'), findsOneWidget);
    expect(find.text('স্বাগতম! ফসলের রোগ এখন ঘরে বসেই শনাক্ত করুন'), findsNothing);

    for (final label in ['ইতিহাস', 'সতর্কতা', 'সেটিংস', 'রোগ শনাক্ত']) {
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }
    expect(find.text('ছবি তুলে রোগ শনাক্ত করুন'), findsOneWidget);
  });
}
