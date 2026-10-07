import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../diagnosis/diagnosis_service.dart';
import '../diagnosis/providers/diagnosis_providers.dart';
import '../history/data/history_dao.dart';
import '../history/data/photo_store.dart';
import '../history/providers/history_provider.dart';
import '../sync/sync_providers.dart';
import '../sync/sync_service.dart';

/// The `deleteMyData` callable.
abstract interface class RemoteEraser {
  Future<void> deleteMyData();
}

class FunctionsEraser implements RemoteEraser {
  @override
  Future<void> deleteMyData() async {
    await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('deleteMyData', options: HttpsCallableOptions(timeout: const Duration(seconds: 60)))
        .call();
  }
}

/// The server could not confirm the deletion; nothing was removed from the phone either.
class DeletionFailed implements Exception {
  const DeletionFailed(this.cause);
  final Object cause;
  @override
  String toString() => 'DeletionFailed($cause)';
}

/// "ইতিহাস মুছুন": removes the farmer's history, photos and reports from the server first, then from the phone.
/// The server goes first on purpose: if it fails (no network), the phone keeps its data and the farmer is told the
/// truth, instead of a phone that looks wiped while copies remain online. Settings and location stay.
class DataDeletion {
  DataDeletion({required this.sync, required this.auth, required this.remote, required this.history, required this.photos});

  final SyncRunner sync;
  final AuthGate auth;
  final RemoteEraser remote;
  final HistoryStore history;
  final PhotoStore photos;

  Future<void> run() async {
    await sync.suspend(); // a sync in flight must not write the data back
    try {
      try {
        await auth.ensureSignedIn();
        await remote.deleteMyData();
      } catch (e) {
        debugPrint('deleteMyData failed: $e');
        throw DeletionFailed(e);
      }
      await photos.delete(await history.deleteAll());
    } finally {
      sync.resume();
    }
  }
}

final dataDeletionProvider = Provider<DataDeletion>((ref) => DataDeletion(
      sync: ref.watch(syncServiceProvider),
      auth: ref.watch(authGateProvider),
      remote: FunctionsEraser(),
      history: ref.watch(historyDaoProvider),
      photos: ref.watch(photoStoreProvider),
    ));
