import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

enum Flavor { dev, stg, prod }

/// Shared startup for the three flavor entry points.
///
/// Anonymous sign-in is NOT awaited here: the app must start offline
/// (Design §6.3). It happens lazily via [anonymousUidProvider].
Future<void> bootstrap(Flavor flavor, FirebaseOptions options) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: options);
  // Debug provider only in dev; Play Integrity for stg/prod (Play-distributed builds).
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        flavor == Flavor.dev ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  );
  runApp(const ProviderScope(child: KrishiApp()));
}
