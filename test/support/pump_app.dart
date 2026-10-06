import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/app.dart';
import 'package:mather_sathi/features/geo/data/districts_repository.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import 'fakes.dart';

/// Pumps the whole app on a phone-sized surface with fake storage.
Future<FakeProfileStore> pumpApp(
  WidgetTester tester, {
  UserProfile? saved,
  List overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final store = FakeProfileStore(saved);
  await tester.pumpWidget(ProviderScope(
    // ignore: argument_type_not_assignable
    overrides: [
      profileStoreProvider.overrideWithValue(store),
      // Read the real file synchronously: rootBundle I/O does not settle under pumpAndSettle.
      districtsProvider.overrideWith((_) =>
          parseDistricts(File('assets/data/districts.json').readAsStringSync())),
      ...overrides,
    ],
    child: const KrishiApp(),
  ));
  await tester.pumpAndSettle();
  return store;
}

const doneProfile = UserProfile(
    district: 'dhaka', upazila: '1', defaultCrop: 'rice', onboardingDone: true);
