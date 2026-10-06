import 'dart:typed_data';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/core_providers.dart';
import '../../capture/domain/crop_selection.dart';
import '../../diagnosis/domain/diagnosis_models.dart';
import '../../kb/domain/kb_models.dart';
import '../../kb/kb_provider.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/photo_store.dart';
import '../domain/diagnosis_record.dart';

const kGeneralAdviceId = 'general_advice';

final photoStoreProvider = Provider<PhotoStore>((ref) => FilePhotoStore());
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final idGeneratorProvider = Provider<String Function()>((ref) => () => const Uuid().v4());

/// Regional reports only carry confident, real diseases from a farmer who has a district and consented.
bool isReportable({required bool consent, required Confidence confidence, required bool isDisease, required String? district}) =>
    consent && isDisease && confidence != Confidence.low && district != null;

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<DiagnosisRecord>>(HistoryNotifier.new);

class HistoryNotifier extends AsyncNotifier<List<DiagnosisRecord>> {
  @override
  Future<List<DiagnosisRecord>> build() => ref.read(historyDaoProvider).list();

  /// Stores the outcome (prepared JPEG, name snapshot, KB seq), enforces the 50-row retention, returns the new id.
  /// [NeedsRetake] is not a diagnosis and is never saved.
  Future<String> saveOutcome(DiagnosisOutcome outcome, CropSelection crop) async {
    final dao = ref.read(historyDaoProvider);
    final profile = ref.read(profileProvider).value ?? UserProfile.initial;
    final kb = await ref.read(kbProvider.future).then<KnowledgeBase?>((k) => k, onError: (_) => null);
    final id = ref.read(idGeneratorProvider)();
    String? nameOf(String diseaseId) => kb == null ? null : kb[diseaseId]?.nameBn;

    final (Uint8List jpeg, DiagnosisRecord Function(String path) build) = switch (outcome) {
      Classified(:final result, :final preparedJpeg) => (
          preparedJpeg,
          (path) => DiagnosisRecord(
                id: id,
                cropType: crop.id,
                diseaseId: result.diseaseId,
                diseaseNameBn: result.isDisease ? nameOf(result.diseaseId) : null,
                kbSeq: result.kbSeq,
                confidence: result.confidence.name,
                source: result.source == DiagnosisSource.cloud ? 'cloud' : 'on_device',
                photoPath: path,
                diagnosedAt: ref.read(clockProvider)().toUtc(),
                district: profile.district,
                upazila: profile.upazila,
                reportState: isReportable(
                  consent: profile.shareReports,
                  confidence: result.confidence,
                  isDisease: result.isDisease,
                  district: profile.district,
                )
                    ? 0
                    : 2,
                photoSynced: !profile.photoBackup && !profile.photoContribute,
              )
        ),
      GeneralAdvice(:final summaryBn, :final preventionBn, :final preparedJpeg) => (
          preparedJpeg,
          (path) => DiagnosisRecord(
                id: id,
                cropType: CropSelection.otherId,
                cropLabel: crop.label,
                diseaseId: kGeneralAdviceId,
                kbSeq: kb?.seq,
                adviceJson: jsonEncode({'summary_bn': summaryBn, 'prevention_bn': preventionBn}),
                source: 'cloud',
                photoPath: path,
                diagnosedAt: ref.read(clockProvider)().toUtc(),
                district: profile.district,
                upazila: profile.upazila,
                reportState: 2,
                photoSynced: !profile.photoBackup && !profile.photoContribute,
              )
        ),
      NeedsRetake() => throw ArgumentError('a retake request is not a diagnosis'),
    };

    final store = ref.read(photoStoreProvider);
    final path = await store.save(id, jpeg);
    try {
      await dao.insert(build(path));
    } catch (_) {
      await store.delete([path]); // no orphan file when the row could not be written
      rethrow;
    }
    await store.delete(await dao.enforceRetention());
    state = AsyncData(await dao.list());
    return id;
  }

  /// "Was this correct?" Re-arms the history sync (`is_synced = 0`). [actual] is the farmer's disease id when it was wrong.
  Future<void> setFeedback(String id, {required bool correct, String? actual}) async {
    await ref.read(historyDaoProvider).setFeedback(id, correct ? 'correct' : 'incorrect', actual: correct ? null : actual);
    ref.invalidate(historyEntryProvider(id));
    state = AsyncData(await ref.read(historyDaoProvider).list());
  }
}

final historyEntryProvider = FutureProvider.family<DiagnosisRecord?, String>(
    (ref, id) => ref.watch(historyDaoProvider).byId(id));
