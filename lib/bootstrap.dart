import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/flags/remote_flags.dart';
import 'core/utils/cold_start.dart';
import 'features/kb/kb_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'providers/core_providers.dart';

enum Flavor { dev, stg, prod }

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

  final db = await AppDatabase.open();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  await Future.wait([
    container.read(profileProvider.future),
    container.read(kbPreloadProvider.future),
  ]);
  unawaited(container.read(remoteFlagsProvider.notifier).refresh());

  ColdStart.logOnFirstFrame();
  runApp(UncontrolledProviderScope(container: container, child: const KrishiApp()));
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
