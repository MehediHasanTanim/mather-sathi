import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/errors/error_reporter.dart';
import 'core/flags/remote_flags.dart';
import 'core/utils/cold_start.dart';
import 'features/kb/kb_provider.dart';
import 'features/offline/memory_guard.dart';
import 'features/offline/model_assets.dart';
import 'features/notifications/topic_sync.dart';
import 'features/sync/sync_providers.dart';
import 'features/profile/providers/profile_provider.dart';
import 'providers/core_providers.dart';

enum Flavor { dev, stg, prod }

/// Dev only: point Functions and Auth at the local Firebase emulators.
/// `flutter run --flavor dev -t lib/main_dev.dart --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=<lan ip>`
/// (10.0.2.2 reaches the host from an Android emulator; use the machine's LAN IP for a physical phone).
const _useEmulators = bool.fromEnvironment('USE_EMULATORS');
const _emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

/// Shared startup for the three flavor entry points.
///
/// Awaited before the first frame: Firebase core init (works offline), the DB,
/// and a preload of the profile (so the router knows if onboarding is done and
/// there is no onboarding flicker) and the KB placeholder.
/// Not awaited (Design §14): App Check, Remote Config, anonymous sign-in.
Future<void> bootstrap(Flavor flavor, FirebaseOptions options) async {
  ColdStart.begin();
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: options);
  unawaited(_activateAppCheck(flavor));
  _setUpCrashReporting();
  if (flavor == Flavor.dev && _useEmulators) {
    FirebaseFunctions.instanceFor(region: 'asia-south1')
        .useFunctionsEmulator(_emulatorHost, 5001);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  }

  final db = await AppDatabase.open();
  final modelAssets = await ModelAssets.probe(
    rootBundle,
    CrashlyticsErrorReporter(),
  );
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      allowDraftKbProvider.overrideWithValue(flavor == Flavor.dev),
      modelAssetsProvider.overrideWithValue(
        modelAssets,
      ), // null: no usable offline model, cloud-only behaviour
    ],
  );
  if (modelAssets != null) {
    WidgetsBinding.instance.addObserver(
      MemoryPressureGuard(() => container.read(localClassifierProvider)),
    );
  }
  await Future.wait([
    container.read(profileProvider.future),
    container.read(kbProvider.future),
  ]);
  unawaited(container.read(remoteFlagsProvider.notifier).refresh());
  unawaited(updateKb(container)); // newer reviewed KB, or a rollback of a bad entry

  await initializeDateFormatting('bn');
  unawaited(
    container.read(syncServiceProvider).flush(),
  ); // app start: push anything left from last time
  unawaited(
    container
        .read(topicSyncProvider)
        .sync(container.read(profileProvider).requireValue),
  ); // retry any failed topic change

  ColdStart.logOnFirstFrame();
  runApp(
    UncontrolledProviderScope(container: container, child: const KrishiApp()),
  );
}

Future<void> _activateAppCheck(Flavor flavor) async {
  try {
    await FirebaseAppCheck.instance.activate(
      // Debug provider only in dev; Play Integrity for stg/prod (Play-distributed builds).
      providerAndroid: flavor == Flavor.dev
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

void _setUpCrashReporting() {
  final crashlytics = FirebaseCrashlytics.instance;
  unawaited(crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode));
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(crashlytics.recordError(error, stack, fatal: true));
    return true;
  };
}
