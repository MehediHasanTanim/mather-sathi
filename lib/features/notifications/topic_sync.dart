import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profile/domain/user_profile.dart';

/// FCM topic for a district slug. Must match `districtTopic` in functions/src/notify.ts.
String districtTopic(String slug) => 'd_$slug';

abstract interface class TopicSubscriber {
  Future<void> subscribe(String topic);
  Future<void> unsubscribe(String topic);

  /// Android 13+ asks for the notification permission; older versions need nothing. Best effort.
  Future<void> requestPermission();
}

class FirebaseTopicSubscriber implements TopicSubscriber {
  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  @override
  Future<void> subscribe(String topic) => _fm.subscribeToTopic(topic);
  @override
  Future<void> unsubscribe(String topic) => _fm.unsubscribeFromTopic(topic);
  @override
  Future<void> requestPermission() => _fm.requestPermission();
}

/// Remembers which topic this install is subscribed to, so changes can be diffed after a restart.
abstract interface class SubscribedTopicStore {
  Future<String?> load();
  Future<void> save(String? topic);
}

class PrefsSubscribedTopicStore implements SubscribedTopicStore {
  static const _key = 'subscribed_topic';

  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String? topic) async {
    final p = await SharedPreferences.getInstance();
    if (topic == null) {
      await p.remove(_key);
    } else {
      await p.setString(_key, topic);
    }
  }
}

abstract interface class TopicSyncRunner {
  Future<void> sync(UserProfile profile);
}

/// Keeps the FCM subscription equal to the profile: subscribed to the farmer's district topic while notifications are
/// on, unsubscribed when they are off or the district changes. Idempotent, serialised, and never throws: a failed step
/// is left unsaved so the next call (app start, next profile change) retries it.
class TopicSync implements TopicSyncRunner {
  TopicSync(this._subscriber, this._store);
  final TopicSubscriber _subscriber;
  final SubscribedTopicStore _store;
  Future<void> _tail = Future.value();

  @override
  Future<void> sync(UserProfile profile) {
    final desired = profile.notifications && profile.district != null
        ? districtTopic(profile.district!)
        : null;
    return _tail = _tail.then((_) => _apply(desired));
  }

  Future<void> _apply(String? desired) async {
    try {
      final current = await _store.load();
      if (current == desired) return;
      if (desired != null)
        await _subscriber.requestPermission().catchError((_) {});
      if (current != null) await _subscriber.unsubscribe(current);
      if (desired != null) await _subscriber.subscribe(desired);
      await _store.save(desired);
    } catch (e) {
      debugPrint('topic sync failed, will retry: $e');
    }
  }
}

final topicSyncProvider = Provider<TopicSyncRunner>(
  (ref) => TopicSync(FirebaseTopicSubscriber(), PrefsSubscribedTopicStore()),
);
