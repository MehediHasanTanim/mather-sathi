import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Remote-tunable values (Design §16.1). Defaults are baked in so the app
/// behaves correctly when Remote Config is unreachable. Threshold defaults are
/// provisional; they are calibrated on field photos in task 9.1.
@immutable
class RemoteFlags {
  const RemoteFlags({
    this.cloudDiagnosisEnabled = true,
    this.confHigh = 0.80,
    this.confMedium = 0.60,
    this.minCropMass = 0.50,
    this.blurThreshold = 60.0,
    this.darkThreshold = 40.0,
    this.ttsRateSlow = 0.40,
    this.ttsRateNormal = 0.50,
    this.ttsRateFast = 0.65,
    this.helplineNumber = '16123',
    this.helplineHoursText = '',
    this.helplineNote = '',
    this.minAppVersion = '',
  });

  static const defaults = RemoteFlags();

  final bool cloudDiagnosisEnabled;
  final double confHigh;
  final double confMedium;
  final double minCropMass;
  final double blurThreshold;
  final double darkThreshold;
  final double ttsRateSlow;
  final double ttsRateNormal;
  final double ttsRateFast;
  final String helplineNumber;
  final String helplineHoursText;
  final String helplineNote;
  final String minAppVersion;

  /// Builds flags from raw key/value pairs, falling back to the default for
  /// any missing or malformed value.
  factory RemoteFlags.fromValues(Map<String, Object?> v) {
    const d = RemoteFlags.defaults;
    double num_(String k, double fallback) {
      final x = v[k];
      if (x is num) return x.toDouble();
      return (x is String ? double.tryParse(x) : null) ?? fallback;
    }

    bool bool_(String k, bool fallback) {
      final x = v[k];
      if (x is bool) return x;
      return switch (x) { 'true' => true, 'false' => false, _ => fallback };
    }

    String str(String k, String fallback) {
      final x = v[k];
      return x is String && x.isNotEmpty ? x : fallback;
    }

    return RemoteFlags(
      cloudDiagnosisEnabled: bool_('cloud_diagnosis_enabled', d.cloudDiagnosisEnabled),
      confHigh: num_('conf_high', d.confHigh),
      confMedium: num_('conf_medium', d.confMedium),
      minCropMass: num_('min_crop_mass', d.minCropMass),
      blurThreshold: num_('blur_threshold', d.blurThreshold),
      darkThreshold: num_('dark_threshold', d.darkThreshold),
      ttsRateSlow: num_('tts_rate_slow', d.ttsRateSlow),
      ttsRateNormal: num_('tts_rate_normal', d.ttsRateNormal),
      ttsRateFast: num_('tts_rate_fast', d.ttsRateFast),
      helplineNumber: str('helpline_number', d.helplineNumber),
      helplineHoursText: str('helpline_hours_text', d.helplineHoursText),
      helplineNote: str('helpline_note', d.helplineNote),
      minAppVersion: str('min_app_version', d.minAppVersion),
    );
  }

  List<Object> get _fields => [
        cloudDiagnosisEnabled, confHigh, confMedium, minCropMass, blurThreshold,
        darkThreshold, ttsRateSlow, ttsRateNormal, ttsRateFast, helplineNumber,
        helplineHoursText, helplineNote, minAppVersion,
      ];

  @override
  bool operator ==(Object other) =>
      other is RemoteFlags && listEquals(other._fields, _fields);

  @override
  int get hashCode => Object.hashAll(_fields);

  /// Remote Config key names, also the keys accepted by `fromValues` (dev overrides). `RemoteFlags.fromValues({...})` keyed by Remote Config names.
  static const keys = [
    'cloud_diagnosis_enabled', 'conf_high', 'conf_medium', 'min_crop_mass',
    'blur_threshold', 'dark_threshold', 'tts_rate_slow', 'tts_rate_normal',
    'tts_rate_fast', 'helpline_number', 'helpline_hours_text', 'helpline_note',
    'min_app_version',
  ];
}

/// Source of remote values; faked in tests.
abstract interface class RemoteConfigSource {
  /// Fetches and activates; throws when unreachable. Returns the current values.
  Future<Map<String, Object?>> fetch();
}

class FirebaseRemoteConfigSource implements RemoteConfigSource {
  FirebaseRemoteConfigSource([FirebaseRemoteConfig? rc])
      : _rc = rc ?? FirebaseRemoteConfig.instance;
  final FirebaseRemoteConfig _rc;

  @override
  Future<Map<String, Object?>> fetch() async {
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 12),
    ));
    await _rc.fetchAndActivate();
    final all = _rc.getAll();
    return {for (final k in RemoteFlags.keys) if (all.containsKey(k)) k: all[k]!.asString()};
  }
}

final remoteConfigSourceProvider =
    Provider<RemoteConfigSource>((ref) => FirebaseRemoteConfigSource());

/// Debug-only overrides (dev flavor); empty in release builds.
final remoteFlagOverridesProvider = Provider<Map<String, Object?>>((ref) => const {});

final remoteFlagsProvider =
    NotifierProvider<RemoteFlagsNotifier, RemoteFlags>(RemoteFlagsNotifier.new);

class RemoteFlagsNotifier extends Notifier<RemoteFlags> {
  @override
  RemoteFlags build() =>
      RemoteFlags.fromValues(ref.read(remoteFlagOverridesProvider));

  /// Background refresh. Never throws: on any failure the current flags stay.
  Future<void> refresh() async {
    try {
      final fetched = await ref.read(remoteConfigSourceProvider).fetch();
      state = RemoteFlags.fromValues(
          {...fetched, ...ref.read(remoteFlagOverridesProvider)});
    } catch (e) {
      debugPrint('RemoteFlags: fetch failed, keeping current values ($e)');
    }
  }
}
