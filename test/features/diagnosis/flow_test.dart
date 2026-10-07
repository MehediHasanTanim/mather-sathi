import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/capture/domain/crop_selection.dart';
import 'package:mather_sathi/features/diagnosis/data/cloud_client.dart';
import 'package:mather_sathi/features/diagnosis/diagnosis_service.dart';
import 'package:mather_sathi/features/diagnosis/domain/diagnosis_models.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';
import 'package:mather_sathi/features/diagnosis/providers/diagnosis_providers.dart';
import 'package:mather_sathi/features/history/providers/history_provider.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/kb/kb_provider.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';
import 'package:mather_sathi/features/profile/providers/profile_provider.dart';
import 'package:mather_sathi/features/sync/sync_providers.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../../support/diagnosis_fakes.dart';
import '../../support/fakes.dart';
import '../../support/phase4_fakes.dart';
import '../../support/pump_app.dart' show NoopSync;

final _jpeg = Uint8List.fromList([1, 2, 3]);
const _rice = CropSelection('rice');

class _FixedKb extends KbNotifier {
  @override
  Future<KnowledgeBase> build() async => testKb();
}

// ignore: invalid_use_of_protected_member
FirebaseFunctionsException fnError(String code) => FirebaseFunctionsException(message: 'm', code: code);

class Env {
  Env(CloudDiagnosisClient cloud) {
    store = InMemoryHistoryStore();
    photos = FakePhotoStore();
    sync = NoopSync();
    container = ProviderContainer(overrides: [
      syncServiceProvider.overrideWithValue(sync),
      historyDaoProvider.overrideWithValue(store),
      photoStoreProvider.overrideWithValue(photos),
      profileStoreProvider.overrideWithValue(FakeProfileStore(const UserProfile(district: 'dhaka', onboardingDone: true))),
      kbProvider.overrideWith(() => _FixedKb()),
      diagnosisServiceProvider.overrideWithValue(DiagnosisService(
        cloud: cloud, local: const NoLocalClassifier(), connectivity: FakeConnectivity(true),
        auth: FakeAuth(), kb: testKb, flags: () => RemoteFlags.defaults,
      )),
    ]);
    states = [];
    container.listen(diagnosisFlowProvider, (_, n) => states.add(n), fireImmediately: false);
  }
  late final InMemoryHistoryStore store;
  late final FakePhotoStore photos;
  late final NoopSync sync;
  late final ProviderContainer container;
  late final List<DiagnosisFlow> states;
  DiagnosisFlowNotifier get flow => container.read(diagnosisFlowProvider.notifier);
  DiagnosisFlow get state => container.read(diagnosisFlowProvider);
  Future<void> ready() async {
    await container.read(profileProvider.future);
    await container.read(kbProvider.future);
  }
}

Future<Env> env(CloudDiagnosisClient cloud) async {
  final e = Env(cloud);
  await e.ready();
  addTearDown(e.container.dispose);
  return e;
}

void main() {
  test('idle → analyzing → saving → done(historyId); the diagnosis is in history', () async {
    final e = await env(fakeCloud(response: cloudClassified('rice_blast')));
    expect(e.state, isA<FlowIdle>());
    await e.flow.submit(_jpeg, _rice);
    expect(e.states.map((s) => s is FlowRunning ? s.stage : s.runtimeType), [FlowStage.analyzing, FlowStage.saving, FlowDone]);
    final id = (e.state as FlowDone).historyId;
    expect((await e.store.byId(id))!.diseaseId, 'rice_blast');
    expect(e.photos.files, hasLength(1));
    expect(e.sync.flushes, 1, reason: 'a successful save requests a background sync');
  });

  test('a retake request ends in FlowRetake and saves nothing', () async {
    final e = await env(fakeCloud(response: cloudClassified('unknown', issue: 'blurry', confidence: 'low')));
    await e.flow.submit(_jpeg, _rice);
    expect((e.state as FlowRetake).issue, ImageIssue.blurry);
    expect(e.store.rows, isEmpty);
    expect(e.photos.files, isEmpty);
    expect(e.sync.flushes, 0);
  });

  test('a failure ends in FlowFailed with the typed failure and saves nothing', () async {
    final e = await env(fakeCloud(throws: fnError('resource-exhausted')));
    await e.flow.submit(_jpeg, _rice);
    expect((e.state as FlowFailed).failure, isA<DailyCapReached>());
    expect(e.store.rows, isEmpty);
  });

  test('a storage failure is a failure state, not a crash', () async {
    final e = await env(fakeCloud(response: cloudClassified('rice_blast')));
    e.photos.failSave = true;
    await e.flow.submit(_jpeg, _rice);
    expect(e.state, isA<FlowFailed>());
  });

  test('a double tap starts one run only', () async {
    var calls = 0;
    final e = await env(fakeCloud(response: cloudClassified('rice_blast'), onCall: (_) => calls++));
    await Future.wait([e.flow.submit(_jpeg, _rice), e.flow.submit(_jpeg, _rice), e.flow.submit(_jpeg, _rice)]);
    expect(calls, 1);
    expect(e.store.rows, hasLength(1));
  });

  test('cancel during analysis is safe: nothing is saved, state is idle, a late result is dropped', () async {
    final gate = Completer<Map<String, dynamic>>();
    final e = await env(CloudDiagnosisClient((_) => gate.future));
    final run = e.flow.submit(_jpeg, _rice);
    await Future<void>.delayed(Duration.zero);
    expect(e.state, isA<FlowRunning>());
    e.flow.cancel();
    expect(e.state, isA<FlowIdle>());
    gate.complete(cloudClassified('rice_blast'));
    await run;
    expect(e.state, isA<FlowIdle>());
    expect(e.store.rows, isEmpty);
    expect(e.photos.files, isEmpty);
  });

  test('after a cancel the next submit works normally', () async {
    final gate = Completer<Map<String, dynamic>>();
    var first = true;
    final e = await env(CloudDiagnosisClient((_) {
      if (first) {
        first = false;
        return gate.future;
      }
      return Future.value(cloudClassified('rice_blast'));
    }));
    final stale = e.flow.submit(_jpeg, _rice);
    await Future<void>.delayed(Duration.zero);
    e.flow.cancel();
    await e.flow.submit(_jpeg, _rice);
    expect(e.state, isA<FlowDone>());
    gate.complete(cloudClassified('healthy'));
    await stale;
    expect(e.state, isA<FlowDone>(), reason: 'the cancelled run must not overwrite the newer result');
    expect(e.store.rows, hasLength(1));
  });

  test('retry re-runs the last submission', () async {
    var calls = 0;
    final e = await env(CloudDiagnosisClient((_) async {
      if (++calls == 1) throw fnError('deadline-exceeded');
      return cloudClassified('rice_blast');
    }));
    await e.flow.submit(_jpeg, _rice);
    expect((e.state as FlowFailed).failure, isA<CloudTimeout>());
    await e.flow.retry();
    expect(e.state, isA<FlowDone>());
    expect(calls, 2);
  });

  test('retry is offered only when it can help', () {
    expect(canRetry(const CloudTimeout()), isTrue);
    expect(canRetry(const ServerError('x')), isTrue);
    expect(canRetry(const NeedsInternet()), isTrue);
    expect(canRetry(const DailyCapReached()), isFalse);
    expect(canRetry(const ServiceRejected()), isFalse);
  });
}
