import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/router/app_router.dart';

class PushNotice {
  const PushNotice({this.title, this.body, this.route});
  final String? title;
  final String? body;

  /// From the message's `route` data field. Untrusted: only [safePushRoute] values are ever navigated to.
  final String? route;
}

/// Routes a push may open. Anything else is ignored, so a push can never steer the app somewhere arbitrary.
const kPushRoutes = {'/alerts'};
String? safePushRoute(String? route) =>
    kPushRoutes.contains(route) ? route : null;

abstract interface class PushSource {
  /// A push that arrived while the app is open (the system shows nothing in that case).
  Stream<PushNotice> get foreground;

  /// The farmer tapped a notification while the app was in the background.
  Stream<PushNotice> get opened;

  /// The notification that launched the app from a closed state, if any.
  Future<PushNotice?> initial();
}

class FirebasePushSource implements PushSource {
  static PushNotice _notice(RemoteMessage m) => PushNotice(
    title: m.notification?.title,
    body: m.notification?.body,
    route: m.data['route'] as String?,
  );

  @override
  Stream<PushNotice> get foreground => FirebaseMessaging.onMessage.map(_notice);
  @override
  Stream<PushNotice> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map(_notice);
  @override
  Future<PushNotice?> initial() async {
    final m = await FirebaseMessaging.instance.getInitialMessage();
    return m == null ? null : _notice(m);
  }
}

final pushSourceProvider = Provider<PushSource>((ref) => FirebasePushSource());

/// The foreground push currently shown as an in-app banner, if any.
final pushBannerProvider = NotifierProvider<PushBannerNotifier, PushNotice?>(
  PushBannerNotifier.new,
);

class PushBannerNotifier extends Notifier<PushNotice?> {
  @override
  PushNotice? build() => null;
  void show(PushNotice n) => state = n;
  void clear() => state = null;
}

/// Deep links and foreground banners for pushes. Created once by the app and kept alive for its lifetime.
final pushHandlerProvider = Provider<void>((ref) {
  final source = ref.watch(pushSourceProvider);
  final router = ref.read(routerProvider);
  final banner = ref.read(pushBannerProvider.notifier);

  void open(PushNotice n) {
    final route = safePushRoute(n.route);
    if (route != null) router.go(route);
  }

  final subs = <StreamSubscription<PushNotice>>[
    source.opened.listen(open),
    source.foreground.listen(banner.show),
  ];
  unawaited(
    source.initial().then((n) {
      if (n != null) open(n);
    }),
  );
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });
});

/// Draws the foreground push on top of the whole app (above every Scaffold and the navigation bar), so it is always
/// visible and tappable. Hides itself after a few seconds.
class PushBannerHost extends ConsumerStatefulWidget {
  const PushBannerHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PushBannerHost> createState() => _PushBannerHostState();
}

class _PushBannerHostState extends ConsumerState<PushBannerHost> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(pushBannerProvider);
    ref.listen(pushBannerProvider, (_, next) {
      _timer?.cancel();
      if (next != null) {
        _timer = Timer(
          const Duration(seconds: 8),
          () => ref.read(pushBannerProvider.notifier).clear(),
        );
      }
    });
    final route = safePushRoute(notice?.route);
    final l = notice == null ? null : AppLocalizations.of(context);
    return Stack(
      children: [
        widget.child,
        if (notice != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  key: const Key('push_banner'),
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (notice.title != null) notice.title!,
                              if (notice.body != null) notice.body!,
                            ].join('\n'),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface,
                            ),
                          ),
                        ),
                        if (route != null)
                          TextButton(
                            key: const Key('push_open'),
                            onPressed: () {
                              ref.read(pushBannerProvider.notifier).clear();
                              ref.read(routerProvider).go(route);
                            },
                            child: Text(l!.pushOpen),
                          ),
                        IconButton(
                          key: const Key('push_close'),
                          icon: Icon(
                            Icons.close,
                            color: Theme.of(context)
                                .colorScheme
                                .onInverseSurface,
                          ),
                          onPressed: ref
                              .read(pushBannerProvider.notifier)
                              .clear,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
