import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/app.dart';
import 'package:mather_sathi/features/geo/data/districts_repository.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import 'package:mather_sathi/features/alerts/providers/alerts_provider.dart';
import 'package:mather_sathi/features/notifications/push_handler.dart';
import 'package:mather_sathi/features/notifications/topic_sync.dart';
import 'package:mather_sathi/features/sync/sync_providers.dart';
import 'package:mather_sathi/features/weather/providers/weather_provider.dart';
import 'package:mather_sathi/features/sync/sync_service.dart';

import 'fakes.dart';
import 'phase7_fakes.dart';

/// Pumps the whole app on a phone-sized surface with fake storage.
Future<FakeProfileStore> pumpApp(
  WidgetTester tester, {
  UserProfile? saved,
  List overrides = const [],
  NoopSync? sync,
  Stream<bool>? connectivity,
  FakePushSource? push,
  FakeTopicSync? topics,
  FakeAlertsSource? alerts,
  FakeWeatherSource? weather,
  FakeDismissStore? dismiss,
}) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final store = FakeProfileStore(saved);
  await tester.pumpWidget(
    ProviderScope(
      // ignore: argument_type_not_assignable
      overrides: [
        profileStoreProvider.overrideWithValue(store),
        // No Firebase in widget tests: sync is a no-op and connectivity never changes unless a test overrides these.
        syncServiceProvider.overrideWithValue(sync ?? NoopSync()),
        connectivityProvider.overrideWith(
          (_) => connectivity ?? const Stream<bool>.empty(),
        ),
        pushSourceProvider.overrideWithValue(push ?? FakePushSource()),
        topicSyncProvider.overrideWithValue(topics ?? FakeTopicSync()),
        // Weather and alerts have no Firebase in widget tests: empty unless a test passes its own sources.
        weatherSourceProvider.overrideWithValue(weather ?? FakeWeatherSource()),
        alertsSourceProvider.overrideWithValue(alerts ?? FakeAlertsSource()),
        weatherDismissStoreProvider.overrideWithValue(
          dismiss ?? FakeDismissStore(),
        ),
        // Read the real file synchronously: rootBundle I/O does not settle under pumpAndSettle.
        districtsProvider.overrideWith(
          (_) => parseDistricts(
            File('assets/data/districts.json').readAsStringSync(),
          ),
        ),
        ...overrides,
      ],
      child: const KrishiApp(),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

const doneProfile = UserProfile(
  district: 'dhaka',
  upazila: '1',
  defaultCrop: 'rice',
  onboardingDone: true,
);

class NoopSync implements SyncRunner {
  int flushes = 0;
  @override
  Future<void> flush() async => flushes++;
  @override
  Future<void> suspend() async {}
  @override
  void resume() {}
}
