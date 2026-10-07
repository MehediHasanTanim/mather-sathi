import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Event sink. Firebase Analytics in the app, a recorder in tests. Logging must never throw or block a farmer's action.
abstract interface class Analytics {
  void log(String name, [Map<String, Object> params = const {}]);
}

class FirebaseAnalyticsSink implements Analytics {
  @override
  void log(String name, [Map<String, Object> params = const {}]) {
    try {
      FirebaseAnalytics.instance.logEvent(name: name, parameters: params).catchError((Object e) => debugPrint('analytics failed: $e'));
    } catch (e) {
      debugPrint('analytics failed: $e'); // Firebase not initialised (tests), or a platform error
    }
  }
}

final analyticsProvider = Provider<Analytics>((ref) => FirebaseAnalyticsSink());

/// Event names and parameters from Design §16.2. No PII and no images: only enums, bucket names, crop ids and numbers.
/// A free-text "other crop" label is never a parameter (it is user-typed); it is reported as `other`.
abstract final class Ev {
  static void diagnosisCompleted(Analytics a, {required String source, required String crop, required String confidence, required int latencyMs, required String outcome}) =>
      a.log('diagnosis_completed', {'source': source, 'crop': crop, 'confidence': confidence, 'latency_ms': latencyMs, 'outcome': outcome});

  static void diagnosisFailed(Analytics a, {required String failure}) => a.log('diagnosis_failed', {'failure': failure});

  static void fallbackToOnDevice(Analytics a, {required String reason}) => a.log('fallback_to_on_device', {'reason': reason});

  static void retakePrompted(Analytics a, {required String issue}) => a.log('retake_prompted', {'issue': issue});

  static void feedbackGiven(Analytics a, {required bool correct, required String source, required String crop}) =>
      a.log('feedback_given', {'correct': correct ? 1 : 0, 'source': source, 'crop': crop});

  static void ttsPlayed(Analytics a) => a.log('tts_played');
  static void expertCallTapped(Analytics a) => a.log('expert_call_tapped');
  static void alertOpened(Analytics a) => a.log('alert_opened');
  static void shareTapped(Analytics a) => a.log('share_tapped');
}
