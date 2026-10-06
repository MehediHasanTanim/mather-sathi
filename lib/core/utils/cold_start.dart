import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

/// Logs time from `main()` to the first rendered frame (task 1.1 baseline).
/// Process-start time is measured separately with `adb shell am start -W`
/// (see docs/perf-baseline.md).
class ColdStart {
  ColdStart._();
  static final Stopwatch _sw = Stopwatch();

  static void begin() => _sw
    ..reset()
    ..start();

  static void logOnFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sw.stop();
      final ms = _sw.elapsedMilliseconds;
      debugPrint('cold_start_first_frame_ms=$ms');
      developer.log('first frame after $ms ms', name: 'cold_start');
    });
  }
}
