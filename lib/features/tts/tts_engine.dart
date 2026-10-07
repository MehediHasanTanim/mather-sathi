import 'package:flutter_tts/flutter_tts.dart';

/// Thin seam over the platform TTS so the controller is testable.
abstract interface class TtsEngine {
  Future<bool> isBanglaInstalled();

  /// Sets the language, speech rate, and makes [speak] complete only when speech finishes (or is stopped).
  Future<void> configure({required double rate});
  Future<void> speak(String text);
  Future<void> stop();
}

class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();
  final FlutterTts _tts;
  static const language = 'bn-BD';

  @override
  Future<bool> isBanglaInstalled() async {
    try {
      return (await _tts.isLanguageInstalled(language)) == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> configure({required double rate}) async {
    await _tts.setLanguage(language);
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}
