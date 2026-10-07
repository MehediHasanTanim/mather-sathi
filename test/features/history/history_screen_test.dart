import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/features/history/domain/diagnosis_record.dart';
import 'package:mather_sathi/features/history/providers/history_provider.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/kb/kb_provider.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../../support/diagnosis_fakes.dart';
import '../../support/phase4_fakes.dart';
import '../../support/pump_app.dart';

class _Kb extends KbNotifier {
  @override
  Future<KnowledgeBase> build() async => testKb(seq: 5);
}

DiagnosisRecord rec(String id, String? disease, {String crop = 'rice', String? name, DateTime? at, String? label, String? photo}) =>
    DiagnosisRecord(
      id: id, cropType: crop, cropLabel: label, diseaseId: disease, diseaseNameBn: name, kbSeq: 5, confidence: 'high',
      source: 'cloud', photoPath: photo, diagnosedAt: at ?? DateTime(2026, 10, 6, 12),
    );

Future<InMemoryHistoryStore> open(WidgetTester tester, List<DiagnosisRecord> rows) async {
  final store = InMemoryHistoryStore();
  for (final r in rows) {
    store.rows[r.id] = r;
  }
  await pumpApp(tester, saved: doneProfile, overrides: [
    historyDaoProvider.overrideWithValue(store),
    kbProvider.overrideWith(() => _Kb()),
  ]);
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('ইতিহাস')));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('an empty history shows a friendly message', (tester) async {
    await open(tester, []);
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });

  testWidgets('rows show thumbnail slot, disease, crop, Bangla date and urgency badge, newest first', (tester) async {
    await open(tester, [
      rec('old', 'potato_early_blight', crop: 'potato', name: 'আলুর আর্লি ব্লাইট', at: DateTime(2026, 10, 1, 9)),
      rec('new', 'rice_blast', name: 'ধানের ব্লাস্ট রোগ', at: DateTime(2026, 10, 6, 12)),
    ]);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles[0].title! as Text).data, 'ধানের ব্লাস্ট রোগ');
    expect((tiles[1].title! as Text).data, 'আলুর আর্লি ব্লাইট');
    expect((tiles[0].subtitle! as Text).data, 'ধান • ৬ অক্টোবর ২০২৬');
    expect((tiles[1].subtitle! as Text).data, 'আলু • ১ অক্টোবর ২০২৬');
    expect(find.text('জরুরি'), findsOneWidget, reason: 'blast is high urgency');
    expect(find.text('নজর রাখুন'), findsOneWidget, reason: 'early blight is medium');
    expect(find.byIcon(Icons.eco), findsNWidgets(2), reason: 'a row without a photo falls back to an icon');
  });

  testWidgets('non-diagnosis rows have their own titles and no urgency badge', (tester) async {
    await open(tester, [
      rec('h', 'healthy', at: DateTime(2026, 10, 6, 3)),
      rec('u', 'unknown', at: DateTime(2026, 10, 6, 2)),
      rec('g', 'general_advice', crop: 'other', label: 'ধনেপাতা', at: DateTime(2026, 10, 6, 1)),
    ]);
    expect(find.text('সুস্থ'), findsOneWidget);
    expect(find.text('নিশ্চিত হওয়া যায়নি'), findsOneWidget);
    expect(find.text('সাধারণ পরামর্শ'), findsOneWidget);
    expect(find.textContaining('ধনেপাতা'), findsOneWidget);
    expect(find.byKey(const Key('urgency_badge')), findsNothing);
  });

  testWidgets('KB drift: an entry removed from the KB still lists with its saved name', (tester) async {
    await open(tester, [rec('x', 'rice_removed', name: 'আগের নাম')]);
    expect(find.text('আগের নাম'), findsOneWidget);
    expect(find.byKey(const Key('urgency_badge')), findsNothing);
    await tester.tap(find.byKey(const Key('history_x')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kb_gone')), findsOneWidget, reason: 'detail shows the "no longer available" message, never a crash');
  });

  testWidgets('tapping a row opens its result', (tester) async {
    await open(tester, [rec('a', 'rice_blast', name: 'ধানের ব্লাস্ট রোগ')]);
    await tester.tap(find.byKey(const Key('history_a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('disease_name')), findsOneWidget);
  });

  testWidgets('a new diagnosis saved while the tab exists appears without reopening the app', (tester) async {
    final store = await open(tester, [rec('a', 'rice_blast', name: 'ধানের ব্লাস্ট রোগ')]);
    final c = ProviderScope.containerOf(tester.element(find.byType(NavigationBar)));
    store.rows['b'] = rec('b', 'potato_early_blight', crop: 'potato', name: 'আলুর আর্লি ব্লাইট', at: DateTime(2026, 10, 7));
    c.invalidate(historyProvider);
    await tester.pumpAndSettle();
    expect(find.text('আলুর আর্লি ব্লাইট'), findsOneWidget);
  });

  testWidgets('going back online triggers a sync', (tester) async {
    final online = StreamController<bool>();
    final sync = NoopSync();
    await pumpApp(tester, saved: doneProfile, sync: sync, connectivity: online.stream);
    Future<void> emit(bool v) async {
      online.add(v);
      await tester.pump();
      await tester.pump();
    }

    await emit(true);
    expect(sync.flushes, 1);
    await emit(true);
    expect(sync.flushes, 1, reason: 'no change, no extra flush');
    await emit(false);
    await emit(true);
    expect(sync.flushes, 2);
  });
}
