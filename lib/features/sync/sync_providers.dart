import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../diagnosis/providers/diagnosis_providers.dart';
import 'sync_remote.dart';
import 'sync_service.dart';

/// Online/offline changes. Only a hint: a phone can be "connected" with no data balance.
final connectivityProvider = StreamProvider<bool>(
  (ref) => Connectivity().onConnectivityChanged.map((r) => !r.every((c) => c == ConnectivityResult.none)),
);

final syncServiceProvider = Provider<SyncRunner>((ref) => SyncService(
      history: ref.watch(historyDaoProvider),
      profile: ref.watch(profileStoreProvider),
      auth: ref.watch(authGateProvider),
      remote: FirestoreSyncRemote(),
      connectivity: ref.watch(connectivityCheckerProvider),
    ));

/// Fire-and-forget flush for callers that must never wait on the network.
void requestSync(Ref ref) => ref.read(syncServiceProvider).flush();

