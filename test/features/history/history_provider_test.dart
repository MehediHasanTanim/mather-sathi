import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/db/app_database.dart';
import 'package:mather_sathi/features/capture/domain/crop_selection.dart';
import 'package:mather_sathi/features/diagnosis/domain/diagnosis_models.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';
import 'package:mather_sathi/features/history/domain/diagnosis_record.dart';

import 'package:mather_sathi/features/history/providers/history_provider.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/kb/kb_provider.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/features/profile/providers/profile_provider.dart';
import 'package:mather_sathi/providers/core_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/diagnosis_fakes.dart';
import '../../support/fakes.dart';
import '../../support/phase4_fakes.dart';

class _FixedKb extends KbNotifier {
  @override
  Future<KnowledgeBase> build() async => testKb(seq: 5);
}


final _jpeg = Uint8List.fromList([9, 8, 7]);
const _profile = UserProfile(district: 'dhaka', upazila: '1', defaultCrop: 'rice', onboardingDone: true);

DiagnosisResult _result(String id, {Confidence c = Confidence.high, DiagnosisSource s = DiagnosisSource.cloud}) =>
    DiagnosisResult(diseaseId: id, confidence: c, source: s, imageIssue: ImageIssue.none, kbSeq: 5);

void main() {
  sqfliteFfiInit();
  late Database db;
  late FakePhotoStore photos;
  late ProviderContainer c;
  var n = 0;

  Future<void> setUpWith(UserProfile profile) async {
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    photos = FakePhotoStore();
    n = 0;
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      profileStoreProvider.overrideWithValue(FakeProfileStore(profile)),
      photoStoreProvider.overrideWithValue(photos),
      kbProvider.overrideWith(() => _FixedKb()),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 1, 1).add(Duration(minutes: n++))),
      idGeneratorProvider.overrideWithValue(() => 'id${n.toString().padLeft(3, '0')}'),
    ]);
    await c.read(profileProvider.future);
    await c.read(kbProvider.future);
  }

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<String> save(DiagnosisOutcome o, [CropSelection crop = const CropSelection('rice')]) =>
      c.read(historyProvider.notifier).saveOutcome(o, crop);
  Future<DiagnosisRecord> row(String id) async => (await c.read(historyDaoProvider).byId(id))!;

  test('a classified disease keeps the name snapshot, KB seq, source and the prepared photo', () async {
    await setUpWith(_profile);
    final id = await save(Classified(_result('rice_blast', c: Confidence.medium, s: DiagnosisSource.onDevice), _jpeg));
    final r = await row(id);
    expect(r.diseaseId, 'rice_blast');
    expect(r.diseaseNameBn, 'ধানের ব্লাস্ট রোগ');
    expect(r.kbSeq, 5);
    expect(r.confidence, 'medium');
    expect(r.source, 'on_device');
    expect(r.district, 'dhaka');
    expect(photos.files[r.photoPath], _jpeg, reason: 'the prepared bytes are what is stored');
    expect(r.isSynced, isFalse);
  });

  test('regional report state is decided at save time', () async {
    await setUpWith(_profile);
    expect((await row(await save(Classified(_result('rice_blast'), _jpeg)))).reportState, 0, reason: 'eligible');
    expect((await row(await save(Classified(_result('rice_blast', c: Confidence.low), _jpeg)))).reportState, 2, reason: 'low confidence');
    expect((await row(await save(Classified(_result('healthy'), _jpeg)))).reportState, 2, reason: 'not a disease');
    expect((await row(await save(Classified(_result('unknown'), _jpeg)))).reportState, 2);
    c.dispose();
    await db.close();
    await setUpWith(_profile.copyWith(shareReports: false));
    expect((await row(await save(Classified(_result('rice_blast'), _jpeg)))).reportState, 2, reason: 'no consent');
  });

  test('no district means not reportable', () async {
    await setUpWith(const UserProfile(onboardingDone: true));
    expect((await row(await save(Classified(_result('rice_blast'), _jpeg)))).reportState, 2);
  });

  test('photo upload is "done" when neither backup nor contribution consent is on', () async {
    await setUpWith(_profile);
    expect((await row(await save(Classified(_result('rice_blast'), _jpeg)))).photoSynced, isTrue);
    c.dispose();
    await db.close();
    await setUpWith(_profile.copyWith(photoBackup: true));
    expect((await row(await save(Classified(_result('rice_blast'), _jpeg)))).photoSynced, isFalse);
  });

  test('general advice is stored as advice_json for the "other" crop and is never reportable', () async {
    await setUpWith(_profile);
    final id = await save(GeneralAdvice('সারাংশ', ['ক', 'খ'], _jpeg), CropSelection.other('ধনেপাতা'));
    final r = await row(id);
    expect(r.cropType, 'other');
    expect(r.cropLabel, 'ধনেপাতা');
    expect(r.diseaseId, kGeneralAdviceId);
    expect(jsonDecode(r.adviceJson!), {'summary_bn': 'সারাংশ', 'prevention_bn': ['ক', 'খ']});
    expect(r.reportState, 2);
  });

  test('a retake request is not a diagnosis and is never saved', () async {
    await setUpWith(_profile);
    await expectLater(save(const NeedsRetake(ImageIssue.blurry)), throwsArgumentError);
    expect(await c.read(historyDaoProvider).count(), 0);
    expect(photos.files, isEmpty);
  });

  test('after 51 saves only 50 rows and 50 photo files remain', () async {
    await setUpWith(_profile);
    final ids = <String>[];
    for (var i = 0; i < 51; i++) {
      ids.add(await save(Classified(_result('rice_blast'), _jpeg)));
    }
    expect(await c.read(historyDaoProvider).count(), 50);
    expect(photos.files.length, 50);
    expect(await c.read(historyDaoProvider).byId(ids.first), isNull);
    expect(photos.deleted, ['/photos/${ids.first}.jpg']);
    expect((await c.read(historyProvider.future)).length, 50);
  });

  test('a failed insert leaves no orphan photo file', () async {
    await setUpWith(_profile);
    await db.close(); // inserts now fail
    await expectLater(save(Classified(_result('rice_blast'), _jpeg)), throwsA(anything));
    expect(photos.files, isEmpty);
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi); // for tearDown
  });

  test('feedback persists, re-arms sync, and keeps the farmer-supplied disease', () async {
    await setUpWith(_profile);
    final id = await save(Classified(_result('rice_blast'), _jpeg));
    await c.read(historyDaoProvider).markSynced(id);
    await c.read(historyProvider.notifier).setFeedback(id, correct: false, actual: 'rice_brown_spot');
    var r = await row(id);
    expect([r.feedback, r.feedbackActual, r.isSynced], ['incorrect', 'rice_brown_spot', false]);

    await c.read(historyProvider.notifier).setFeedback(id, correct: true, actual: 'ignored');
    r = await row(id);
    expect([r.feedback, r.feedbackActual], ['correct', null]);
    expect((await c.read(historyEntryProvider(id).future))!.feedback, 'correct');
  });
}
