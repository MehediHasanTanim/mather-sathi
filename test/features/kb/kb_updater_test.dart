import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/features/kb/data/kb_repository.dart';
import 'package:mather_sathi/features/kb/data/kb_updater.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';

import '../../support/diagnosis_fakes.dart';
import '../result/result_screen_test.dart' show entry;

String sha(String s) => sha256.convert(utf8.encode(s)).toString();

class FakeKbSource implements KbSource {
  KbPointer? pointer;
  final files = <String, Uint8List>{};
  Object? throwsOnCurrent;
  Object? throwsOnDownload;
  int downloads = 0;

  void publish(String json, {int? seq, String? sha256Override, String path = 'kb/kb_2.json', int minSchema = 1}) {
    final s = seq ?? (jsonDecode(json)['seq'] as int);
    files[path] = Uint8List.fromList(utf8.encode(json));
    pointer = KbPointer(seq: s, sha256: sha256Override ?? sha(json), path: path, minAppSchema: minSchema);
  }

  @override
  Future<KbPointer?> current() async {
    if (throwsOnCurrent != null) throw throwsOnCurrent!;
    return pointer;
  }

  @override
  Future<Uint8List> download(String path, {required int maxBytes}) async {
    downloads++;
    if (throwsOnDownload != null) throw throwsOnDownload!;
    return files[path] ?? (throw StateError('no such object'));
  }
}

void main() {
  late Directory dir;
  late File live;
  late FakeKbSource source;
  late FakeReporter reporter;
  var current = 1;

  KbUpdater updater({bool allowDrafts = false}) =>
      KbUpdater(source: source, reporter: reporter, currentSeq: () => current, allowDrafts: allowDrafts, localFile: () async => live);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kb_upd');
    live = File('${dir.path}/kb/kb.json');
    source = FakeKbSource();
    reporter = FakeReporter();
    current = 1;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a newer, verified KB is installed and then loaded by the repository', () async {
    source.publish(kbJson(seq: 2));
    expect(await updater().check(), KbUpdateResult.updated);
    final repo = KbRepository(reporter: reporter, localFile: () async => live, loadAsset: () async => kbJson(seq: 1));
    expect((await repo.load()).seq, 2);
    expect(File('${live.path}.tmp').existsSync(), isFalse, reason: 'the temp file was renamed away');
  });

  test('same or older seq, or no pointer: nothing is downloaded', () async {
    expect(await updater().check(), KbUpdateResult.upToDate);
    source.publish(kbJson(seq: 1));
    expect(await updater().check(), KbUpdateResult.upToDate);
    current = 5;
    source.publish(kbJson(seq: 3));
    expect(await updater().check(), KbUpdateResult.upToDate);
    expect(source.downloads, 0);
  });

  test('a checksum mismatch is refused, reported, and leaves the live file untouched', () async {
    live.createSync(recursive: true);
    live.writeAsStringSync(kbJson(seq: 1));
    source.publish(kbJson(seq: 2), sha256Override: sha('something else'));
    expect(await updater().check(), KbUpdateResult.failed);
    expect(live.readAsStringSync(), kbJson(seq: 1));
    expect(reporter.reports.single, contains('checksum'));
  });

  test('a file whose bytes were tampered with after publishing is refused', () async {
    source.publish(kbJson(seq: 2));
    source.files['kb/kb_2.json'] = Uint8List.fromList(utf8.encode(kbJson(seq: 2).replaceFirst('ধানের', 'ধানের (বদলানো)')));
    expect(await updater().check(), KbUpdateResult.failed);
    expect(live.existsSync(), isFalse);
  });

  test('correct checksum but not a valid KB: refused (the checksum proves integrity, not validity)', () async {
    const junk = '{"schema":1,"seq":2,"version":"v","entries":[{"id":"x"}]}';
    source.publish(junk);
    expect(await updater().check(), KbUpdateResult.failed);
    expect(live.existsSync(), isFalse);
  });

  test('a KB the app is too old for is skipped quietly', () async {
    source.publish(kbJson(seq: 2), minSchema: 2);
    expect(await updater().check(), KbUpdateResult.skipped);
    expect(source.downloads, 0);
    expect(reporter.reports, isEmpty);
  });

  test('a pointer seq that disagrees with the file is refused', () async {
    source.publish(kbJson(seq: 2), seq: 9);
    expect(await updater().check(), KbUpdateResult.failed);
  });

  test('draft entries are refused outside dev and accepted in dev', () async {
    source.publish(kbJson(seq: 2, drafts: true));
    expect(await updater().check(), KbUpdateResult.failed);
    expect(await updater(allowDrafts: true).check(), KbUpdateResult.updated);
  });

  test('a pointer cannot send the app to an arbitrary storage path', () async {
    for (final bad in ['../secrets.json', 'backups/u1/x.jpg', 'kb/../x.json', 'kb/a/b.json', 'https://evil.example/kb.json']) {
      source.publish(kbJson(seq: 2), path: bad);
      expect(await updater().check(), KbUpdateResult.failed, reason: bad);
    }
    expect(source.downloads, 0);
  });

  test('a malformed pointer (bad hash) is refused', () async {
    source.publish(kbJson(seq: 2), sha256Override: 'nothex');
    expect(await updater().check(), KbUpdateResult.failed);
    expect(source.downloads, 0);
  });

  test('offline or a storage error never throws', () async {
    source.throwsOnCurrent = Exception('offline');
    expect(await updater().check(), KbUpdateResult.failed);
    source.throwsOnCurrent = null;
    source.publish(kbJson(seq: 2));
    source.throwsOnDownload = Exception('timeout');
    expect(await updater().check(), KbUpdateResult.failed);
    expect(live.existsSync(), isFalse);
  });

  test('KB ROLLBACK DRILL: a bad entry is hidden by publishing a higher seq in which it is not published', () async {
    final bad = [entry('rice_blast', 'rice', 'ধানের ব্লাস্ট রোগ', 'high'), entry('rice_brown_spot', 'rice', 'ধানের বাদামি দাগ', 'medium')];
    source.publish(jsonEncode({...jsonDecode(kbJson(seq: 2, entries: bad)) as Map, 'seq': 2}));
    expect(await updater().check(), KbUpdateResult.updated);
    final repo = KbRepository(reporter: reporter, localFile: () async => live, loadAsset: () async => kbJson(seq: 1));
    var kb = await repo.load();
    expect(kb['rice_brown_spot']!.published, isTrue);

    // Incident: brown spot advice is wrong. Hide it with seq 3 (no app release).
    current = kb.seq;
    // The publisher's real output for that situation: the entry is simply absent from the prod build.
    source.publish(kbJson(seq: 3, entries: [bad[0]]), path: 'kb/kb_3.json');
    expect(await updater().check(), KbUpdateResult.updated);
    kb = await repo.load();
    expect(kb.seq, 3);
    expect(kb['rice_brown_spot'], isNull, reason: 'the entry is gone from the app; old history rows show the "entry removed" message');
    expect(kb['rice_blast'], isNotNull);
  });

  test('it signs in first (the rules need it) and does nothing quietly when sign-in is impossible', () async {
    source.publish(kbJson(seq: 2));
    final auth = FakeAuth();
    final u = KbUpdater(source: source, reporter: reporter, currentSeq: () => current, auth: auth, localFile: () async => live);
    expect(await u.check(), KbUpdateResult.updated);
    expect(auth.calls, 1);

    live.deleteSync();
    final offline = KbUpdater(source: source, reporter: reporter, currentSeq: () => current, auth: FakeAuth()..throws = Exception('offline'), localFile: () async => live);
    source.downloads = 0;
    expect(await offline.check(), KbUpdateResult.failed);
    expect(source.downloads, 0);
    expect(reporter.reports, isEmpty, reason: 'being offline on a fresh install is not a crash-worthy event');
  });

  test('KnowledgeBase parse is what vets the file (schema newer than supported)', () {
    expect(() => KnowledgeBase.parse(kbJson(seq: 2, schema: 9)), throwsA(anything));
  });
}
