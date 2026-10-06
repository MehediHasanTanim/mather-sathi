import 'package:flutter/widgets.dart';

import '../diagnosis/diagnosis_service.dart';
import 'tflite_classifier.dart';

/// Frees the interpreter when Android signals low memory; it reloads on the next offline diagnosis.
class MemoryPressureGuard with WidgetsBindingObserver {
  MemoryPressureGuard(this._classifier);
  final LocalClassifier Function() _classifier;

  @override
  void didHaveMemoryPressure() {
    final c = _classifier();
    if (c is TfliteClassifier) c.release();
  }
}
