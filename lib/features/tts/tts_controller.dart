import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flags/remote_flags.dart';
import '../profile/providers/profile_provider.dart';
import 'tts_engine.dart';
import 'tts_script.dart';
import '../../core/analytics/analytics.dart';

enum TtsStatus { idle, speaking, paused, unavailable }

final ttsEngineProvider = Provider<TtsEngine>((ref) => FlutterTtsEngine());
final ttsControllerProvider = NotifierProvider<TtsController, TtsStatus>(TtsController.new);

/// Reads a script aloud in chunks. Android's pause support is unreliable, so pause is
/// "stop, and resume from the start of the current chunk". A generation counter makes sure a quick
/// pause/resume can never leave two playback loops running.
class TtsController extends Notifier<TtsStatus> {
  List<String> _chunks = const [];
  int _i = 0;
  int _gen = 0;
  Future<void>? _stopping;

  late final TtsEngine _engine;

  @override
  TtsStatus build() {
    _engine = ref.read(ttsEngineProvider); // captured: Ref cannot be used inside onDispose
    ref.onDispose(() {
      _gen++;
      _engine.stop();
    });
    return TtsStatus.idle;
  }

  double _rate() {
    final f = ref.read(remoteFlagsProvider);
    return switch (ref.read(profileProvider).value?.ttsSpeed) {
      'slow' => f.ttsRateSlow,
      'fast' => f.ttsRateFast,
      _ => f.ttsRateNormal,
    };
  }

  Future<void> speak(String script) async {
    Ev.ttsPlayed(ref.read(analyticsProvider));
    final gen = ++_gen;
    await _engine.stop();
    await _engine.configure(rate: _rate());
    if (gen != _gen) return; // superseded while configuring
    if (!await _engine.isBanglaInstalled()) {
      if (gen == _gen) state = TtsStatus.unavailable;
      return;
    }
    _chunks = splitSentences(script, maxLen: 300);
    _i = 0;
    unawaited(_play()); // returns once playback has started, not when it ends
  }

  Future<void> _play() async {
    final gen = ++_gen;
    state = TtsStatus.speaking;
    try {
      while (_i < _chunks.length && gen == _gen) {
        await _engine.speak(_chunks[_i]);
        if (gen == _gen) _i++;
      }
    } catch (e) {
      debugPrint('TTS failed: $e');
    }
    if (gen == _gen) {
      _i = 0;
      state = TtsStatus.idle;
    }
  }

  Future<void> pause() async {
    if (state != TtsStatus.speaking) return;
    _gen++;
    state = TtsStatus.paused;
    await (_stopping = _engine.stop());
  }

  Future<void> resume() async {
    if (state != TtsStatus.paused) return;
    await _stopping; // never start the next utterance while the previous one is still being stopped
    if (state != TtsStatus.paused) return;
    unawaited(_play());
  }

  Future<void> stop() async {
    _gen++;
    _i = 0;
    state = TtsStatus.idle;
    await _engine.stop();
  }

  /// Called after the "no Bangla voice" dialog was shown.
  void acknowledgeUnavailable() {
    if (state == TtsStatus.unavailable) state = TtsStatus.idle;
  }
}
