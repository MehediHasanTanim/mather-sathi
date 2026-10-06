import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/features/diagnosis/data/cloud_client.dart';
import 'package:mather_sathi/features/diagnosis/domain/diagnosis_models.dart';
import 'package:mather_sathi/features/diagnosis/domain/image_issue.dart';

import '../../support/diagnosis_fakes.dart';

// ignore: invalid_use_of_protected_member
FirebaseFunctionsException fnError(String code) => FirebaseFunctionsException(message: 'm', code: code);

void main() {
  group('failure mapping (Design §6.5)', () {
    final table = <String, Matcher>{
      'deadline-exceeded': isA<CloudTimeout>(),
      'resource-exhausted': isA<DailyCapReached>(),
      'unauthenticated': isA<ServiceRejected>(),
      'permission-denied': isA<ServiceRejected>(),
      'unavailable': isA<ServerError>(),
      'internal': isA<ServerError>(),
      'invalid-argument': isA<ServerError>(),
      'some-new-code': isA<ServerError>(),
    };
    for (final e in table.entries) {
      test('${e.key} maps correctly', () async {
        final client = fakeCloud(throws: fnError(e.key));
        await expectLater(client.diagnose(Uint8List(3), 'rice'), throwsA(e.value));
      });
    }

    test('ServerError keeps the code for logging', () {
      expect((mapFunctionsCode('unavailable') as ServerError).code, 'unavailable');
    });

    test('a malformed response is a server error, not a crash', () async {
      final client = fakeCloud(response: {'mode': 'weird'});
      await expectLater(client.diagnose(Uint8List(3), 'rice'), throwsA(isA<ServerError>()));
    });
  });

  test('sends base64 image and the crop parameter', () async {
    Map<String, dynamic>? sent;
    final client = fakeCloud(response: cloudClassified('rice_blast'), onCall: (p) => sent = p);
    await client.diagnose(Uint8List.fromList([1, 2, 3]), 'other:ধনেপাতা');
    expect(sent!['crop'], 'other:ধনেপাতা');
    expect(base64Decode(sent!['image'] as String), [1, 2, 3]);
  });

  test('parses a classified response', () async {
    final r = await fakeCloud(response: cloudClassified('rice_blast', confidence: 'medium', issue: 'blurry', kbSeq: 7))
        .diagnose(Uint8List(1), 'rice') as CloudClassified;
    expect(r.diseaseId, 'rice_blast');
    expect(r.confidence, Confidence.medium);
    expect(r.imageIssue, ImageIssue.blurry);
    expect(r.kbSeq, 7);
  });

  test('parses a general-advice response', () async {
    final r = await fakeCloud(response: {
      'mode': 'general', 'summary_bn': 'সারাংশ', 'prevention_bn': ['ক', 'খ'], 'image_issue': 'not_a_plant', 'see_expert': true,
    }).diagnose(Uint8List(1), 'other:x') as CloudGeneral;
    expect(r.summaryBn, 'সারাংশ');
    expect(r.preventionBn, ['ক', 'খ']);
    expect(r.imageIssue, ImageIssue.notAPlant);
  });

  test('wire values map to enums; garbage is safe', () {
    expect(parseImageIssue('too_dark'), ImageIssue.tooDark);
    expect(parseImageIssue('wrong_crop'), ImageIssue.wrongCrop);
    expect(parseImageIssue('???'), ImageIssue.none);
    expect(parseImageIssue(null), ImageIssue.none);
    expect(parseConfidence('high'), Confidence.high);
    expect(parseConfidence('maybe'), Confidence.low);
  });
}
