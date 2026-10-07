import 'package:sqflite/sqflite.dart';

import '../domain/user_profile.dart';

/// Persistence boundary for the profile; faked in widget tests.
abstract interface class ProfileStore {
  /// Returns null when nothing has been saved yet.
  Future<UserProfile?> load();
  Future<void> save(UserProfile profile);
}

class ProfileDao implements ProfileStore {
  ProfileDao(this._db);
  final Database _db;

  @override
  Future<UserProfile?> load() async {
    final rows = await _db.query('user_profile', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  @override
  Future<void> save(UserProfile profile) => _db
      .insert('user_profile', profile.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
}
