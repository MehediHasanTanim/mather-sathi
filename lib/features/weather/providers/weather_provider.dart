import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import '../data/weather_source.dart';
import '../domain/weather_info.dart';

final weatherSourceProvider = Provider<WeatherSource>(
  (ref) => FirestoreWeatherSource(),
);
final weatherDismissStoreProvider = Provider<WeatherDismissStore>(
  (ref) => PrefsWeatherDismissStore(),
);

/// Live outlook for the farmer's own district. Re-subscribes when the district changes.
final weatherProvider = StreamProvider.autoDispose<WeatherInfo?>((ref) {
  final district = ref.watch(profileProvider.select((p) => p.value?.district));
  if (district == null) return Stream.value(null);
  return ref.watch(weatherSourceProvider).watch(district);
});

/// Ms timestamp of the forecast the farmer dismissed; null if none.
final weatherDismissedProvider =
    AsyncNotifierProvider<WeatherDismissNotifier, int?>(
      WeatherDismissNotifier.new,
    );

class WeatherDismissNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() => ref.read(weatherDismissStoreProvider).load();

  Future<void> dismiss(DateTime fetchedAt) async {
    final ms = fetchedAt.millisecondsSinceEpoch;
    await ref.read(weatherDismissStoreProvider).save(ms);
    state = AsyncData(ms);
  }
}

/// The risk to show on the home banner: for the primary crop only, hidden once dismissed for this forecast.
class WeatherBanner {
  const WeatherBanner(this.risk, this.fetchedAt);
  final WeatherRisk risk;
  final DateTime fetchedAt;
}

final weatherBannerProvider = Provider.autoDispose<WeatherBanner?>((ref) {
  final info = ref.watch(weatherProvider).value;
  final crop = ref.watch(profileProvider.select((p) => p.value?.defaultCrop));
  final dismissed = ref.watch(weatherDismissedProvider).value;
  if (info == null) return null;
  final risk = info.forCrop(crop);
  if (risk == null) return null;
  if (dismissed != null && dismissed >= info.fetchedAt.millisecondsSinceEpoch)
    return null;
  return WeatherBanner(risk, info.fetchedAt);
});
