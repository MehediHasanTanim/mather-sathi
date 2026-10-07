import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/analytics/analytics.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/capture/domain/crop_selection.dart';
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
import '../../support/phase8_fakes.dart';
import '../../support/pump_app.dart' show NoopSync;

final _jpeg = Uint8List.fromList([1, 2, 3]);

// ignore: invalid_use_of_protected_member
FirebaseFunctionsException fnError(String code) => FirebaseFunctionsException(message: 'm', code: code);

class _Kb extends KbNotifier {
  @override
  Future<KnowledgeBase> build() async => testKb();
}

Future<(ProviderContainer, RecordingAnalytics, InMemoryHistoryStore)> env({
  Object? cloudThrows,
  Map<String, dynamic>? response,
  bool localAvailable = false,
  bool online = true,
}) async {
  final a = RecordingAnalytics();
  final store = InMemoryHistoryStore();
  final c = ProviderContainer(overrides: [
    analyticsProvider.overrideWithValue(a),
    syncServiceProvider.overrideWithValue(NoopSync()),
    historyDaoProvider.overrideWithValue(store),
    photoStoreProvider.overrideWithValue(FakePhotoStore()),
    profileStoreProvider.overrideWithValue(FakeProfileStore(const UserProfile(district: 'dhaka', onboardingDone: true))),
    kbProvider.overrideWith(_Kb.new),
    diagnosisServiceProvider.overrideWithValue(DiagnosisService(
      cloud: fakeCloud(response: response ?? cloudClassified('rice_blast'), throws: cloudThrows),
      local: FakeLocal(available: localAvailable, result: const DiagnosisResult(
          diseaseId: 'rice_blast', confidence: Confidence.medium, source: DiagnosisSource.onDevice, imageIssue: ImageIssue.none, kbSeq: 1)),
      connectivity: FakeConnectivity(online), auth: FakeAuth(), kb: testKb, flags: () => RemoteFlags.defaults, analytics: a,
    )),
  ]);
  addTearDown(c.dispose);
  await c.read(profileProvider.future);
  await c.read(kbProvider.future);
  return (c, a, store);
}

void main() {
  const rice = CropSelection('rice');

  test('a cloud diagnosis logs diagnosis_completed with source, crop, confidence, latency and outcome', () async {
    final (c, a, _) = await env();
    await c.read(diagnosisFlowProvider.notifier).submit(_jpeg, rice);
    final p = a.only('diagnosis_completed');
    expect([p['source'], p['crop'], p['confidence'], p['outcome']], ['cloud', 'rice', 'high', 'classified']);
    expect(p['latency_ms'], isA<int>());
    expect(a.names, ['diagnosis_completed']);
  });

  test('a failure logs diagnosis_failed with a stable name, and no completed event', () async {
    final (c, a, _) = await env(cloudThrows: fnError('resource-exhausted'));
    await c.read(diagnosisFlowProvider.notifier).submit(_jpeg, rice);
    expect(a.only('diagnosis_failed'), {'failure': 'daily_cap'});
    expect(a.names, ['diagnosis_failed']);
  });

  test('falling back to the on-device model logs the reason', () async {
    final (c, a, _) = await env(cloudThrows: fnError('deadline-exceeded'), localAvailable: true);
    await c.read(diagnosisFlowProvider.notifier).submit(_jpeg, rice);
    expect(a.only('fallback_to_on_device'), {'reason': 'cloud_timeout'});
    expect(a.only('diagnosis_completed')['source'], 'on_device');
  });

  test('offline use of the on-device model is logged as reason offline', () async {
    final (c, a, _) = await env(online: false, localAvailable: true);
    await c.read(diagnosisFlowProvider.notifier).submit(_jpeg, rice);
    expect(a.only('fallback_to_on_device'), {'reason': 'offline'});
  });

  test('a server retake request logs retake_prompted with the issue', () async {
    final (c, a, _) = await env(response: cloudClassified('unknown', issue: 'blurry', confidence: 'low'));
    await c.read(diagnosisFlowProvider.notifier).submit(_jpeg, rice);
    expect(a.only('retake_prompted'), {'issue': 'blurry'});
    expect(a.names, ['retake_prompted']);
  });

  test('an other-crop diagnosis never reports the typed label', () async {
    final (c, a, _) = await env(response: {'mode': 'general', 'summary_bn': 'x', 'prevention_bn': ['y']});
    await c.read(diagnosisFlowProvider.notifier).submit(_jpeg, CropSelection.other('ধনেপাতা'));
    final p = a.only('diagnosis_completed');
    expect([p['crop'], p['outcome']], ['other', 'general']);
    expect(p.values.whereType<String>().any((v) => v.contains('ধনে')), isFalse);
  });

  test('feedback logs correctness, source and crop', () async {
    final (c, a, store) = await env();
    await c.read(diagnosisFlowProvider.notifier).submit(_jpeg, rice);
    final id = (c.read(diagnosisFlowProvider) as FlowDone).historyId;
    await c.read(historyProvider.notifier).setFeedback(id, correct: false, actual: 'rice_brown_spot');
    expect(a.only('feedback_given'), {'correct': 0, 'source': 'cloud', 'crop': 'rice'});
    expect(store.rows[id]!.feedback, 'incorrect');
  });

  test('no event carries free text: every parameter value is a number or a short snake_case token', () async {
    final (c, a, _) = await env(response: {'mode': 'general', 'summary_bn': 'বাংলা টেক্সট', 'prevention_bn': ['y']});
    await c.read(diagnosisFlowProvider.notifier).submit(_jpeg, CropSelection.other('ধনেপাতা'));
    for (final e in a.events) {
      for (final v in e.params.values) {
        expect(v is num || (v is String && RegExp(r'^[a-z0-9_]{1,30}$').hasMatch(v)), isTrue, reason: '${e.name}: $v');
      }
    }
  });
}
