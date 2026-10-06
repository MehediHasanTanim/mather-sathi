import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/db/app_database.dart';
import 'package:mather_sathi/features/history/data/history_dao.dart';
import 'package:mather_sathi/features/history/domain/diagnosis_record.dart';
import 'package:mather_sathi/features/profile/data/profile_store.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DiagnosisRecord rec(int i, {String? photo}) => DiagnosisRecord(
      id: 'id$i',
      cropType: 'rice',
      source: 'cloud',
      diagnosedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
      photoPath: photo ?? '/photos/$i.jpg',
    );

void main() {
  sqfliteFfiInit();
  late Database db;
  late HistoryDao history;

  setUp(() async {
    db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    history = HistoryDao(db);
  });
  tearDown(() => db.close());

  group('history', () {
    test('insert, byId and list order (newest first)', () async {
      for (var i = 0; i < 3; i++) {
        await history.insert(rec(i));
      }
      expect((await history.byId('id1'))!.cropType, 'rice');
      expect((await history.list()).map((r) => r.id), ['id2', 'id1', 'id0']);
      expect(await history.byId('nope'), isNull);
    });

    test('retention keeps the newest 50 and returns deleted photo paths', () async {
      for (var i = 0; i < 51; i++) {
        await history.insert(rec(i));
      }
      final deleted = await history.enforceRetention();
      expect(deleted, ['/photos/0.jpg']);
      expect(await history.count(), 50);
      expect(await history.byId('id0'), isNull);
      expect(await history.byId('id50'), isNotNull);
    });

    test('retention is a no-op at or below the limit', () async {
      for (var i = 0; i < 50; i++) {
        await history.insert(rec(i));
      }
      expect(await history.enforceRetention(), isEmpty);
      expect(await history.count(), 50);
    });

    test('retention skips rows without a photo path', () async {
      await history.insert(DiagnosisRecord(
          id: 'a', cropType: 'rice', source: 'cloud', diagnosedAt: DateTime.utc(2026)));
      await history.insert(rec(5));
      expect(await history.enforceRetention(keep: 1), isEmpty);
      expect(await history.count(), 1);
    });

    test('feedback re-arms sync; pending and mark helpers work', () async {
      await history.insert(rec(1));
      await history.markSynced('id1');
      await history.markReported('id1');
      await history.markPhotoSynced('id1');
      expect(await history.pending(), isEmpty);

      await history.setFeedback('id1', 'incorrect', actual: 'rice_blast');
      final r = (await history.byId('id1'))!;
      expect(r.feedback, 'incorrect');
      expect(r.feedbackActual, 'rice_blast');
      expect(r.isSynced, isFalse);
      expect((await history.pending()).map((x) => x.id), ['id1']);
    });
  });

  group('profile', () {
    test('load is null before first save, then round-trips', () async {
      final dao = ProfileDao(db);
      expect(await dao.load(), isNull);
      const p = UserProfile(
          district: 'dhaka', upazila: '42', defaultCrop: 'rice', onboardingDone: true);
      await dao.save(p);
      expect(await dao.load(), p);
      await dao.save(p.copyWith(photoBackup: true));
      expect((await dao.load())!.photoBackup, isTrue);
    });

    test('defaults: reports on, backup off, contribution off', () {
      expect(UserProfile.initial.shareReports, isTrue);
      expect(UserProfile.initial.photoBackup, isFalse);
      expect(UserProfile.initial.photoContribute, isFalse);
    });
  });

  test('migration runner applies steps in order', () async {
    final log = <int>[];
    await AppDatabase.runMigrations(db, 1, 3, [
      (_) async => log.add(2),
      (_) async => log.add(3),
    ]);
    expect(log, [2, 3]);
  });
}
