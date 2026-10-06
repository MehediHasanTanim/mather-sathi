import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/features/notifications/push_handler.dart';
import 'package:mather_sathi/features/notifications/topic_sync.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/features/profile/providers/profile_provider.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../../support/fakes.dart';
import '../../support/phase7_fakes.dart';
import '../../support/pump_app.dart';

const _p = UserProfile(
  district: 'dhaka',
  upazila: '365',
  defaultCrop: 'rice',
  onboardingDone: true,
);

void main() {
  test('districtTopic matches the topic the Functions publish to', () {
    expect(districtTopic('dhaka'), 'd_dhaka');
    expect(districtTopic('coxsbazar'), 'd_coxsbazar');
  });

  group('TopicSync (task 7.5)', () {
    late FakeSubscriber sub;
    late FakeTopicStore store;
    late TopicSync sync;
    setUp(() {
      sub = FakeSubscriber();
      store = FakeTopicStore();
      sync = TopicSync(sub, store);
    });

    test('first sync subscribes to the district topic and asks for the notification permission', () async {
      await sync.sync(_p);
      expect(sub.calls, ['permission', 'sub:d_dhaka']);
      expect(store.topic, 'd_dhaka');
    });

    test(
      'syncing again with nothing changed does nothing (idempotent)',
      () async {
        await sync.sync(_p);
        sub.calls.clear();
        await sync.sync(_p);
        await sync.sync(_p.copyWith(defaultCrop: 'potato'));
        expect(sub.calls, isEmpty);
      },
    );

    test('changing the district swaps topics: unsubscribe the old, subscribe the new', () async {
      await sync.sync(_p);
      sub.calls.clear();
      await sync.sync(_p.copyWith(district: 'khulna'));
      expect(sub.calls, ['permission', 'unsub:d_dhaka', 'sub:d_khulna']);
      expect(store.topic, 'd_khulna');
    });

    test(
      'turning notifications off unsubscribes, and back on subscribes again',
      () async {
        await sync.sync(_p);
        sub.calls.clear();
        await sync.sync(_p.copyWith(notifications: false));
        expect(sub.calls, ['unsub:d_dhaka']);
        expect(store.topic, isNull);
        sub.calls.clear();
        await sync.sync(_p);
        expect(sub.calls, ['permission', 'sub:d_dhaka']);
      },
    );

    test('no district means no topic, and nothing is subscribed', () async {
      await sync.sync(const UserProfile(onboardingDone: true));
      expect(sub.calls, isEmpty);
    });

    test(
      'a failed subscribe is not recorded, so the next sync retries it',
      () async {
        sub.failOn = 'subscribe';
        await sync.sync(_p); // must not throw
        expect(store.topic, isNull);
        sub.failOn = null;
        sub.calls.clear();
        await sync.sync(_p);
        expect(sub.calls, contains('sub:d_dhaka'));
        expect(store.topic, 'd_dhaka');
      },
    );

    test(
      'a failed unsubscribe keeps the old topic recorded and is retried',
      () async {
        await sync.sync(_p);
        sub.failOn = 'unsubscribe';
        await sync.sync(_p.copyWith(district: 'khulna'));
        expect(store.topic, 'd_dhaka');
        sub.failOn = null;
        await sync.sync(_p.copyWith(district: 'khulna'));
        expect(store.topic, 'd_khulna');
      },
    );

    test(
      'rapid successive changes are applied in order, one at a time',
      () async {
        final a = sync.sync(_p);
        final b = sync.sync(_p.copyWith(district: 'khulna'));
        final c = sync.sync(_p.copyWith(district: 'sylhet'));
        await Future.wait([a, b, c]);
        expect(store.topic, 'd_sylhet');
        expect(sub.calls.where((e) => e.startsWith('sub:')).toList(), [
          'sub:d_dhaka',
          'sub:d_khulna',
          'sub:d_sylhet',
        ]);
      },
    );
  });

  group('ProfileNotifier drives the topic sync', () {
    test(
      'every profile change is synced, including onboarding completion',
      () async {
        final topics = FakeTopicSync();
        final c = ProviderContainer(
          overrides: [
            profileStoreProvider.overrideWithValue(FakeProfileStore()),
            topicSyncProvider.overrideWithValue(topics),
          ],
        );
        addTearDown(c.dispose);
        await c.read(profileProvider.future);
        await c
            .read(profileProvider.notifier)
            .completeOnboarding(_p.copyWith(onboardingDone: false));
        await c
            .read(profileProvider.notifier)
            .change((p) => p.copyWith(district: 'khulna'));
        expect(topics.synced.map((p) => p.district), ['dhaka', 'khulna']);
        expect(topics.synced.last.onboardingDone, isTrue);
      },
    );
  });

  group('push handling (task 7.5)', () {
    test('only allow-listed routes can be opened by a push', () {
      expect(safePushRoute('/alerts'), '/alerts');
      for (final bad in [
        null,
        '',
        '/settings',
        '/result/abc',
        'https://evil.example',
        '/alerts/../settings',
        '//alerts',
      ]) {
        expect(safePushRoute(bad), isNull, reason: '$bad');
      }
    });

    testWidgets(
      'tapping a push while the app is in the background opens the alerts tab',
      (tester) async {
        final push = FakePushSource();
        await pumpApp(tester, saved: doneProfile, push: push);
        expect(find.byKey(const Key('take_photo')), findsOneWidget);
        push.openedController.add(
          const PushNotice(title: 't', body: 'b', route: '/alerts'),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('alerts_empty')), findsOneWidget);
      },
    );

    testWidgets(
      'a push that launched the app from closed opens the alerts tab',
      (tester) async {
        final push = FakePushSource()
          ..launch = const PushNotice(route: '/alerts');
        await pumpApp(tester, saved: doneProfile, push: push);
        expect(find.byKey(const Key('alerts_empty')), findsOneWidget);
      },
    );

    testWidgets('a push with an unknown route does not navigate', (
      tester,
    ) async {
      final push = FakePushSource();
      await pumpApp(tester, saved: doneProfile, push: push);
      push.openedController.add(const PushNotice(route: '/settings'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('take_photo')), findsOneWidget);
    });

    testWidgets(
      'a foreground push shows a banner on top of the app, with an open action',
      (tester) async {
        final push = FakePushSource();
        await pumpApp(tester, saved: doneProfile, push: push);
        push.foregroundController.add(
          const PushNotice(
            title: '🚨 আপনার এলাকায় রোগবালাই',
            body: 'সাভার উপজেলায় ধান',
            route: '/alerts',
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('push_banner')), findsOneWidget);
        expect(find.textContaining('সাভার উপজেলায় ধান'), findsOneWidget);
        await tester.tap(find.byKey(const Key('push_open')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('alerts_empty')), findsOneWidget);
        expect(
          find.byKey(const Key('push_banner')),
          findsNothing,
          reason: 'opening dismisses the banner',
        );
      },
    );

    testWidgets('the banner can be closed and hides itself after 8 seconds', (
      tester,
    ) async {
      final push = FakePushSource();
      await pumpApp(tester, saved: doneProfile, push: push);
      push.foregroundController.add(
        const PushNotice(title: 't', body: 'b', route: '/alerts'),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('push_close')));
      await tester.pump();
      expect(find.byKey(const Key('push_banner')), findsNothing);

      push.foregroundController.add(
        const PushNotice(title: 't2', body: 'b2', route: '/alerts'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('push_banner')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.byKey(const Key('push_banner')), findsNothing);
    });

    testWidgets('a foreground push without a valid route has no open action', (
      tester,
    ) async {
      final push = FakePushSource();
      await pumpApp(tester, saved: doneProfile, push: push);
      push.foregroundController.add(
        const PushNotice(title: 't', body: 'b', route: '/settings'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('push_banner')), findsOneWidget);
      expect(find.byKey(const Key('push_open')), findsNothing);
    });
  });
}
