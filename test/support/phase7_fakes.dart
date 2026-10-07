import 'dart:async';

import 'package:mather_sathi/features/alerts/data/alerts_source.dart';
import 'package:mather_sathi/features/alerts/domain/alert.dart';
import 'package:mather_sathi/features/notifications/push_handler.dart';
import 'package:mather_sathi/features/notifications/topic_sync.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/features/weather/data/weather_source.dart';
import 'package:mather_sathi/features/weather/domain/weather_info.dart';

class FakeAlertsSource implements AlertsSource {
  FakeAlertsSource([this.controller]);
  final StreamController<List<Alert>>? controller;
  final watched = <String>[];

  @override
  Stream<List<Alert>> watch(String districtSlug) {
    watched.add(districtSlug);
    return controller?.stream ?? Stream.value(const <Alert>[]);
  }
}

class FakeWeatherSource implements WeatherSource {
  FakeWeatherSource([this.controller]);
  final StreamController<WeatherInfo?>? controller;
  final watched = <String>[];

  @override
  Stream<WeatherInfo?> watch(String districtSlug) {
    watched.add(districtSlug);
    return controller?.stream ?? Stream.value(null);
  }
}

class FakeDismissStore implements WeatherDismissStore {
  int? value;
  @override
  Future<int?> load() async => value;
  @override
  Future<void> save(int fetchedAtMs) async => value = fetchedAtMs;
}

class FakePushSource implements PushSource {
  final foregroundController = StreamController<PushNotice>.broadcast();
  final openedController = StreamController<PushNotice>.broadcast();
  PushNotice? launch;

  @override
  Stream<PushNotice> get foreground => foregroundController.stream;
  @override
  Stream<PushNotice> get opened => openedController.stream;
  @override
  Future<PushNotice?> initial() async => launch;
}

class FakeTopicSync implements TopicSyncRunner {
  final synced = <UserProfile>[];
  @override
  Future<void> sync(UserProfile profile) async => synced.add(profile);
}

class FakeSubscriber implements TopicSubscriber {
  final calls = <String>[];
  Object? failOn;
  @override
  Future<void> subscribe(String topic) async {
    if (failOn == 'subscribe') throw Exception('offline');
    calls.add('sub:$topic');
  }

  @override
  Future<void> unsubscribe(String topic) async {
    if (failOn == 'unsubscribe') throw Exception('offline');
    calls.add('unsub:$topic');
  }

  @override
  Future<void> requestPermission() async => calls.add('permission');
}

class FakeTopicStore implements SubscribedTopicStore {
  String? topic;
  @override
  Future<String?> load() async => topic;
  @override
  Future<void> save(String? t) async => topic = t;
}
