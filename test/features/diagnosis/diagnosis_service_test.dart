import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/capture/domain/crop_selection.dart';
import 'package:mather_sathi/features/diagnosis/diagnosis_service.dart';
import 'package:mather_sathi/features/diagnosis/domain/diagnosis_models.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';

import '../../support/diagnosis_fakes.dart';

final _jpeg = Uint8List.fromList([1, 2, 3]);
const _rice = CropSelection('rice');
final _other = CropSelection.other('ধনেপাতা');

// ignore: invalid_use_of_protected_member
FirebaseFunctionsException fnError(String code) => FirebaseFunctionsException(message: 'm', code: code);

DiagnosisResult _local(String id, {Confidence c = Confidence.medium}) => DiagnosisResult(
    diseaseId: id, confidence: c, source: DiagnosisSource.onDevice, imageIssue: ImageIssue.none, kbSeq: 1);

DiagnosisService svc({
  bool online = true,
  Object? cloudThrows,
  Map<String, dynamic>? cloudResponse,
  bool localAvailable = false,
  FakeAuth? auth,
  RemoteFlags flags = RemoteFlags.defaults,
  KnowledgeBase? kb,
}) =>
    DiagnosisService(
      cloud: fakeCloud(response: cloudResponse ?? cloudClassified('rice_blast'), throws: cloudThrows),
      local: FakeLocal(available: localAvailable, result: _local('rice_blast')),
      connectivity: FakeConnectivity(online),
      auth: auth ?? FakeAuth(),
      kb: () => kb ?? testKb(),
      flags: () => flags,
    );

Future<Object> outcome(Future<DiagnosisOutcome> f) => f.then<Object>((o) => o, onError: (Object e) => e);

void main() {
  group('fallback matrix (plan task 5.3), cloud part live, on-device stubbed by FakeLocal', () {
    test('1: online + launch crop + cloud OK → cloud result, source cloud', () async {
      final o = await svc().run(_jpeg, _rice) as Classified;
      expect(o.result.source, DiagnosisSource.cloud);
      expect(o.result.diseaseId, 'rice_blast');
      expect(o.result.kbSeq, 1);
    });

    test('2: cloud timeout + on-device available → on-device result', () async {
      final o = await svc(cloudThrows: fnError('deadline-exceeded'), localAvailable: true).run(_jpeg, _rice) as Classified;
      expect(o.result.source, DiagnosisSource.onDevice);
    });

    test('3: cloud timeout / server error + no on-device → the failure surfaces', () async {
      expect(await outcome(svc(cloudThrows: fnError('deadline-exceeded')).run(_jpeg, _rice)), isA<CloudTimeout>());
      expect(await outcome(svc(cloudThrows: fnError('internal')).run(_jpeg, _rice)), isA<ServerError>());
    });

    test('4: daily cap + on-device → on-device', () async {
      final o = await svc(cloudThrows: fnError('resource-exhausted'), localAvailable: true).run(_jpeg, _rice);
      expect((o as Classified).result.source, DiagnosisSource.onDevice);
    });

    test('5: daily cap + no on-device → cap message', () async {
      expect(await outcome(svc(cloudThrows: fnError('resource-exhausted')).run(_jpeg, _rice)), isA<DailyCapReached>());
    });

    test('6: service rejected + on-device → on-device', () async {
      final o = await svc(cloudThrows: fnError('permission-denied'), localAvailable: true).run(_jpeg, _rice);
      expect((o as Classified).result.source, DiagnosisSource.onDevice);
      expect(await outcome(svc(cloudThrows: fnError('unauthenticated')).run(_jpeg, _rice)), isA<ServiceRejected>());
    });

    test('7: offline + launch crop + on-device → on-device', () async {
      final o = await svc(online: false, localAvailable: true).run(_jpeg, _rice);
      expect((o as Classified).result.source, DiagnosisSource.onDevice);
    });

    test('8: offline + launch crop + no on-device → OfflineModelMissing', () async {
      expect(await outcome(svc(online: false).run(_jpeg, _rice)), isA<OfflineModelMissing>());
    });

    test('9: offline + other crop → NeedsInternet (even with an on-device model)', () async {
      expect(await outcome(svc(online: false, localAvailable: true).run(_jpeg, _other)), isA<NeedsInternet>());
    });

    test('10: online + other crop + cloud error → failure, never on-device', () async {
      final local = FakeLocal(available: true, result: _local('rice_blast'));
      final s = DiagnosisService(
        cloud: fakeCloud(throws: fnError('internal')), local: local, connectivity: FakeConnectivity(true),
        auth: FakeAuth(), kb: testKb, flags: () => RemoteFlags.defaults,
      );
      expect(await outcome(s.run(_jpeg, _other)), isA<ServerError>());
      expect(local.calls, 0);
    });

    test('cloud kill switch in Remote Config skips the cloud', () async {
      final auth = FakeAuth();
      final s = svc(flags: const RemoteFlags(cloudDiagnosisEnabled: false), auth: auth);
      expect(await outcome(s.run(_jpeg, _rice)), isA<OfflineModelMissing>());
      expect(auth.calls, 0);
    });
  });

  group('lazy anonymous auth', () {
    test('signs in right before the cloud call, not when offline', () async {
      final auth = FakeAuth();
      await svc(auth: auth).run(_jpeg, _rice);
      expect(auth.calls, 1);
      final offline = FakeAuth();
      await outcome(svc(online: false, auth: offline).run(_jpeg, _rice));
      expect(offline.calls, 0);
    });

    test('an auth failure is a service error (or falls back), never a crash', () async {
      expect(await outcome(svc(auth: FakeAuth()..throws = Exception('no auth')).run(_jpeg, _rice)), isA<ServerError>());
      final o = await svc(auth: FakeAuth()..throws = Exception('x'), localAvailable: true).run(_jpeg, _rice);
      expect((o as Classified).result.source, DiagnosisSource.onDevice);
    });
  });

  group('turning cloud responses into outcomes', () {
    test('general advice for other crops', () async {
      final o = await svc(cloudResponse: {
        'mode': 'general', 'summary_bn': 'সারাংশ', 'prevention_bn': ['ক'], 'image_issue': 'none',
      }).run(_jpeg, _other) as GeneralAdvice;
      expect(o.summaryBn, 'সারাংশ');
      expect(o.preventionBn, ['ক']);
    });

    test('a disease id this app does not know (newer server KB) becomes unknown/low', () async {
      final o = await svc(cloudResponse: cloudClassified('rice_new_disease')).run(_jpeg, _rice) as Classified;
      expect(o.result.diseaseId, kUnknown);
      expect(o.result.confidence, Confidence.low);
    });

    test('healthy passes through', () async {
      final o = await svc(cloudResponse: cloudClassified('healthy')).run(_jpeg, _rice) as Classified;
      expect(o.result.diseaseId, kHealthy);
      expect(o.result.isDisease, isFalse);
    });

    test('unknown with a photo problem asks for a retake', () async {
      final o = await svc(cloudResponse: cloudClassified('unknown', issue: 'wrong_crop', confidence: 'low')).run(_jpeg, _rice);
      expect((o as NeedsRetake).issue, ImageIssue.wrongCrop);
    });

    test('unknown without a photo problem is a normal result', () async {
      final o = await svc(cloudResponse: cloudClassified('unknown', confidence: 'low')).run(_jpeg, _rice);
      expect(o, isA<Classified>());
    });

    test('a disease with an image issue is still a diagnosis', () async {
      final o = await svc(cloudResponse: cloudClassified('rice_blast', issue: 'blurry', confidence: 'low')).run(_jpeg, _rice);
      expect(o, isA<Classified>());
    });
  });
}
