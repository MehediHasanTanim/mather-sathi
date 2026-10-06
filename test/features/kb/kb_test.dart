import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/features/kb/data/kb_repository.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';

import '../../support/diagnosis_fakes.dart';

void main() {
  group('KnowledgeBase.parse', () {
    test('parses entries and exposes lookups', () {
      final kb = KnowledgeBase.parse(kbJson(seq: 5));
      expect(kb.seq, 5);
      expect(kb['rice_blast']!.nameBn, 'ধানের ব্লাস্ট রোগ');
      expect(kb['rice_blast']!.urgency, Urgency.high);
      expect(kb['rice_blast']!.seeExpert, isTrue);
      expect(kb['nope'], isNull);
      expect(kb.forCrop('potato').map((d) => d.id), ['potato_early_blight']);
      expect(kb.supportsCrop('rice'), isTrue);
      expect(kb.supportsCrop('jute'), isFalse);
      expect(kb.includesDrafts, isFalse);
    });

    test('reads the real generated assets/kb/kb.json, including the draft flag', () {
      final kb = KnowledgeBase.parse(File('assets/kb/kb.json').readAsStringSync());
      expect(kb.all, isNotEmpty);
      expect(kb.includesDrafts, kb.all.any((d) => !d.published));
      expect(kb.supportsCrop('rice'), isTrue);
    });

    test('medicine placeholders from draft seeds parse (null pre-harvest days)', () {
      final kb = KnowledgeBase.parse(File('assets/kb/kb.json').readAsStringSync());
      expect(kb.all.expand((d) => d.medicine).every((m) => m.preHarvestIntervalDays == null || m.preHarvestIntervalDays! >= 0), isTrue);
    });

    for (final bad in <String, String>{
      'not json': '{ nope',
      'root not an object': '[]',
      'no schema': '{"seq":1,"version":"v","entries":[]}',
      'newer schema': kbJson(schema: 99),
      'missing entries': '{"schema":1,"seq":1,"version":"v"}',
      'duplicate ids': () {
        final one = jsonDecode(kbJson()) as Map<String, dynamic>;
        final e = (one['entries'] as List).first;
        one['entries'] = [e, e];
        return jsonEncode(one);
      }(),
      'bad urgency': kbJson().replaceFirst('"urgency":"high"', '"urgency":"extreme"'),
      'entry missing a field': kbJson().replaceFirst('"name_bn"', '"nome_bn"'),
      'field of the wrong type': kbJson().replaceFirst('"see_expert":true', '"see_expert":"yes"'),
    }.entries) {
      test('rejects: ${bad.key}', () {
        expect(() => KnowledgeBase.parse(bad.value), throwsA(isA<KbFormatException>()));
      });
    }
  });

  group('KbRepository.load', () {
    late Directory tmp;
    late FakeReporter reporter;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('kb_repo');
      reporter = FakeReporter();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    KbRepository repo({String? local, String? asset}) {
      final f = File('${tmp.path}/kb.json');
      if (local != null) f.writeAsStringSync(local);
      return KbRepository(reporter: reporter, localFile: () async => f, loadAsset: () async => asset ?? kbJson(seq: 1));
    }

    test('no local file: uses the bundled asset', () async {
      final kb = await repo().load();
      expect(kb.seq, 1);
      expect(reporter.reports, isEmpty);
    });

    test('a valid, newer local file wins', () async {
      expect((await repo(local: kbJson(seq: 4)).load()).seq, 4);
    });

    test('a stale local file loses to a newer bundled asset (after an app update)', () async {
      expect((await repo(local: kbJson(seq: 2), asset: kbJson(seq: 9)).load()).seq, 9);
    });

    test('a corrupt local file falls back to the bundled asset and is reported', () async {
      final kb = await repo(local: '{ corrupt').load();
      expect(kb.seq, 1);
      expect(reporter.reports.single, contains('KB local file unusable'));
    });

    test('a local KB with an unsupported schema is ignored and reported', () async {
      final kb = await repo(local: kbJson(seq: 50, schema: 2)).load();
      expect(kb.seq, 1);
      expect(reporter.reports, hasLength(1));
    });

    test('a corrupt bundled asset is a hard error (a build bug)', () async {
      expect(() => repo(asset: 'broken').load(), throwsA(isA<KbFormatException>()));
    });
  });
}
