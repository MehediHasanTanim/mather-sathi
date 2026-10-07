import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../diagnosis/diagnosis_service.dart' show AuthGate;

import '../domain/weather_info.dart';

abstract interface class WeatherSource {
  Stream<WeatherInfo?> watch(String districtSlug);
}

class FirestoreWeatherSource implements WeatherSource {
  FirestoreWeatherSource({this.auth, FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  /// The rules need a signed-in user; sign-in is lazy, so the banner signs in first.
  final AuthGate? auth;

  @override
  Stream<WeatherInfo?> watch(String districtSlug) async* {
    try {
      await auth?.ensureSignedIn();
    } catch (_) {
      // Offline: still open the stream so cached data shows.
    }
    yield* _db.doc('weather/$districtSlug').snapshots().map((s) {
      final d = s.data();
      if (d == null) return null;
      return WeatherInfo.tryParse({
        for (final e in d.entries)
          e.key: e.value is Timestamp ? (e.value as Timestamp).toDate() : e.value,
      });
    });
  }
}

/// Remembers which forecast the farmer dismissed, so the banner stays hidden until new data arrives.
abstract interface class WeatherDismissStore {
  Future<int?> load();
  Future<void> save(int fetchedAtMs);
}

class PrefsWeatherDismissStore implements WeatherDismissStore {
  static const _key = 'weather_dismissed_fetch_ms';

  @override
  Future<int?> load() async =>
      (await SharedPreferences.getInstance()).getInt(_key);

  @override
  Future<void> save(int fetchedAtMs) async =>
      (await SharedPreferences.getInstance()).setInt(_key, fetchedAtMs);
}
