import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../features/history/data/history_dao.dart';
import '../features/profile/data/profile_store.dart';

/// Opened in `bootstrap()` and injected via an override.
final databaseProvider = Provider<Database>(
    (ref) => throw UnimplementedError('databaseProvider must be overridden'));

final profileStoreProvider =
    Provider<ProfileStore>((ref) => ProfileDao(ref.watch(databaseProvider)));

final historyDaoProvider =
    Provider<HistoryDao>((ref) => HistoryDao(ref.watch(databaseProvider)));
