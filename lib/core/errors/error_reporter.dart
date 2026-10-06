import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Non-fatal error sink (KB parse failures, model load failures, ...). Crashlytics in the app, fakes in tests.
abstract interface class ErrorReporter {
  Future<void> record(Object error, StackTrace? stack, {String? reason});
}

class CrashlyticsErrorReporter implements ErrorReporter {
  @override
  Future<void> record(Object error, StackTrace? stack, {String? reason}) async {
    debugPrint('non-fatal: ${reason ?? ''} $error');
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
    } catch (_) {
      // Reporting must never throw into the caller (e.g. Firebase not initialised in tests).
    }
  }
}

final errorReporterProvider = Provider<ErrorReporter>((ref) => CrashlyticsErrorReporter());
