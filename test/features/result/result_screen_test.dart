import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mather_sathi/features/history/domain/diagnosis_record.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/kb/kb_provider.dart';
import 'package:mather_sathi/features/tts/tts_controller.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../../support/diagnosis_fakes.dart';
import '../../support/phase4_fakes.dart';
import '../../support/pump_app.dart';

class _Kb extends KbNotifier {
  _Kb(this.kb);
  final KnowledgeBase kb;
  @override
  Future<KnowledgeBase> build() async => kb;
}

Map<String, Object?> entry(String id, String crop, String name, String urgency,
        {bool medicine = true, bool seeExpert = false, String status = 'published'}) =>
    {
      'id': id, 'crop': crop, 'status': status, 'name_bn': name, 'name_en': id, 'ai_hint_en': 'x',
      'description_bn': 'বিবরণ: $name', 'symptoms_bn': ['লক্ষণ ১', 'লক্ষণ ২'], 'cause_bn': 'কারণ', 'urgency': urgency,
      'immediate_bn': ['এখনই করুন ১'],
      'medicine': medicine
          ? [{'name_bn': 'ওষুধ ক', 'active_ingredient': 'x', 'dose_bn': '২ গ্রাম', 'interval_bn': '৭ দিন পর পর', 'pre_harvest_interval_days': 7}]
          : <Object?>[],
      'prevention_bn': ['প্রতিরোধ ১', 'প্রতিরোধ ২'], 'see_expert': seeExpert,
      'source': 's', 'reviewed_by': 'r', 'reviewed_at': '2026-01-01',
    };

KnowledgeBase kbOf(List<Map<String, Object?>> entries, {int seq = 5, bool drafts = false}) =>
    KnowledgeBase.parse(kbJson(seq: seq, drafts: drafts, entries: entries));

DiagnosisRecord rec(String? diseaseId, {String confidence = 'high', int? kbSeq = 5, String crop = 'rice', String? name, String? advice, String? label}) =>
    DiagnosisRecord(
      id: 'r1', cropType: crop, cropLabel: label, diseaseId: diseaseId, diseaseNameBn: name, kbSeq: kbSeq,
      confidence: confidence, source: 'cloud', photoPath: '/no/such/file.jpg', diagnosedAt: DateTime.utc(2026), adviceJson: advice,
    );

final _std = [
  entry('rice_blast', 'rice', 'ধানের ব্লাস্ট রোগ', 'high', seeExpert: false),
  entry('rice_brown_spot', 'rice', 'ধানের বাদামি দাগ', 'medium', medicine: false),
  entry('rice_sheath', 'rice', 'শিথ ব্লাইট', 'low'),
];

late InMemoryHistoryStore store;
late FakeTtsEngine tts;

Future<void> open(WidgetTester tester, DiagnosisRecord? r, {KnowledgeBase? kb}) async {
  store = InMemoryHistoryStore();
  if (r != null) store.rows[r.id] = r;
  tts = FakeTtsEngine();
  await pumpApp(tester, saved: doneProfile, overrides: [
    historyDaoProvider.overrideWithValue(store),
    kbProvider.overrideWith(() => _Kb(kb ?? kbOf(_std))),
    ttsEngineProvider.overrideWithValue(tts),
  ]);
  tester.view.physicalSize = const Size(1080, 9000); // tall enough that the lazy ListView builds every section
  unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/result/${r?.id ?? 'missing'}'));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester t, String key) => t.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  group('disease result (spec §2.4 checklist)', () {
    testWidgets('high confidence, reviewed entry with medicine: every KB section is rendered', (tester) async {
      await open(tester, rec('rice_blast'));
      expect(textOf(tester, 'disease_name'), 'ধানের ব্লাস্ট রোগ');
      expect(textOf(tester, 'confidence_text'), 'নিশ্চিতমাত্রা বেশি ✅');
      expect(textOf(tester, 'urgency_text'), 'জরুরি চিকিৎসা দরকার');
      expect(find.byKey(const Key('tts_listen')), findsOneWidget);
      expect(find.text('বিবরণ: ধানের ব্লাস্ট রোগ'), findsOneWidget);
      expect(find.text('• লক্ষণ ১'), findsOneWidget);
      expect(find.text('• এখনই করুন ১'), findsOneWidget);
      expect(find.byKey(const Key('medicine_card')), findsOneWidget);
      expect(find.textContaining('ওষুধ ক'), findsOneWidget);
      expect(find.textContaining('২ গ্রাম'), findsOneWidget);
      expect(find.textContaining('৭ দিন পর পর'), findsOneWidget);
      expect(find.textContaining('৭ দিন'), findsWidgets, reason: 'pre-harvest interval, in Bangla digits');
      expect(find.byKey(const Key('safety_line')), findsOneWidget);
      expect(find.text('• প্রতিরোধ ১'), findsOneWidget);
      expect(find.byKey(const Key('ai_disclaimer')), findsOneWidget);
      expect(find.text('ফলাফলটি কি সঠিক ছিল?'), findsOneWidget);
      expect(find.byKey(const Key('draft_banner')), findsNothing);
      expect(find.byKey(const Key('expert_cta')), findsNothing, reason: 'high confidence and see_expert=false');
    });

    testWidgets('see_expert in the KB shows the expert prompt even at high confidence', (tester) async {
      await open(tester, rec('rice_blast'), kb: kbOf([entry('rice_blast', 'rice', 'ধানের ব্লাস্ট রোগ', 'high', seeExpert: true)]));
      expect(find.byKey(const Key('expert_cta')), findsOneWidget);
    });

    testWidgets('medium and low confidence buckets show their own text and the expert prompt', (tester) async {
      await open(tester, rec('rice_blast', confidence: 'medium'));
      expect(textOf(tester, 'confidence_text'), 'সম্ভাব্য রোগ ⚠️ — বিশেষজ্ঞকে দেখান');
      expect(find.byKey(const Key('expert_cta')), findsOneWidget);
      await open(tester, rec('rice_blast', confidence: 'low'));
      expect(textOf(tester, 'confidence_text'), 'ছবি থেকে নিশ্চিত হওয়া যায়নি — আরও কাছ থেকে ছবি তুলুন');
      expect(find.byKey(const Key('expert_cta')), findsOneWidget);
    });

    testWidgets('urgency is shown as text and an icon, not colour alone', (tester) async {
      await open(tester, rec('rice_brown_spot'));
      expect(textOf(tester, 'urgency_text'), 'দ্রুত নজর দিন');
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      await open(tester, rec('rice_sheath'));
      expect(textOf(tester, 'urgency_text'), 'প্রতিরোধমূলক ব্যবস্থা নিন');
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await open(tester, rec('rice_blast'));
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('an entry without medicine has no medicine section and no safety line', (tester) async {
      await open(tester, rec('rice_brown_spot'));
      expect(find.byKey(const Key('medicine_card')), findsNothing);
      expect(find.byKey(const Key('safety_line')), findsNothing);
      expect(find.text('• এখনই করুন ১'), findsOneWidget, reason: 'immediate actions still shown');
    });

    testWidgets('a draft (unreviewed) entry shows the banner and never its medicine', (tester) async {
      await open(tester, rec('rice_blast'), kb: kbOf([entry('rice_blast', 'rice', 'ধানের ব্লাস্ট রোগ', 'high', status: 'draft')], drafts: true));
      expect(find.byKey(const Key('draft_banner')), findsOneWidget);
      expect(find.byKey(const Key('medicine_card')), findsNothing);
      expect(find.byKey(const Key('safety_line')), findsNothing);
    });

    testWidgets('KB drift: a removed entry keeps the saved name and a message, never crashes', (tester) async {
      await open(tester, rec('rice_removed', name: 'আগের নাম'));
      expect(textOf(tester, 'disease_name'), 'আগের নাম');
      expect(find.byKey(const Key('kb_gone')), findsOneWidget);
    });

    testWidgets('KB drift: a newer KB shows "তথ্য হালনাগাদ হয়েছে"', (tester) async {
      await open(tester, rec('rice_blast', kbSeq: 2), kb: kbOf(_std, seq: 9));
      expect(find.byKey(const Key('kb_updated')), findsOneWidget);
      await open(tester, rec('rice_blast', kbSeq: 9), kb: kbOf(_std, seq: 9));
      expect(find.byKey(const Key('kb_updated')), findsNothing);
    });

    testWidgets('an unknown id (not in the KB, no snapshot) does not crash', (tester) async {
      await open(tester, rec('mystery'));
      expect(find.byKey(const Key('kb_gone')), findsOneWidget);
    });
  });

  group('non-diagnosis states (spec §2.6)', () {
    testWidgets('healthy: message plus prevention tips from the crop\'s reviewed KB entries', (tester) async {
      await open(tester, rec('healthy'));
      expect(textOf(tester, 'result_healthy'), 'আপনার ফসলে কোনো পরিচিত রোগ দেখা যায়নি 🌿');
      expect(find.text('প্রতিরোধের পরামর্শ'), findsOneWidget);
      expect(find.text('• প্রতিরোধ ১'), findsOneWidget);
      expect(find.byKey(const Key('medicine_card')), findsNothing);
    });

    testWidgets('unknown: message, hint and the two calls to action', (tester) async {
      await open(tester, rec('unknown', confidence: 'low'));
      expect(textOf(tester, 'result_unknown'), 'নিশ্চিত হওয়া যায়নি');
      expect(find.textContaining('কৃষি কর্মকর্তার সাথে যোগাযোগ করুন'), findsOneWidget);
      expect(find.byKey(const Key('unknown_retry')), findsOneWidget);
      expect(find.byKey(const Key('expert_button')), findsOneWidget);
    });

    testWidgets('general advice for another crop: summary, prevention, expert prompt, no medicine', (tester) async {
      await open(tester, rec('general_advice', crop: 'other', label: 'ধনেপাতা', confidence: 'low',
          advice: '{"summary_bn":"পাতায় দাগ আছে।","prevention_bn":["ক্ষেত পরিষ্কার রাখুন"]}'));
      expect(find.text('ধনেপাতা'), findsOneWidget);
      expect(textOf(tester, 'general_summary'), 'পাতায় দাগ আছে।');
      expect(find.text('• ক্ষেত পরিষ্কার রাখুন'), findsOneWidget);
      expect(find.byKey(const Key('expert_cta')), findsOneWidget);
      expect(find.byKey(const Key('medicine_card')), findsNothing);
    });

    testWidgets('corrupt advice_json does not crash the screen', (tester) async {
      await open(tester, rec('general_advice', crop: 'other', advice: '{ nope'));
      expect(find.byKey(const Key('expert_cta')), findsOneWidget);
    });

    testWidgets('a missing history entry shows a message', (tester) async {
      await open(tester, null);
      expect(find.text('ফলাফল পাওয়া যায়নি'), findsOneWidget);
    });
  });

  group('feedback (task 4.5)', () {
    testWidgets('👍 is saved, shows thanks, re-arms sync, and is still selected on re-open', (tester) async {
      final r = rec('rice_blast');
      await open(tester, r);
      await store.markSynced('r1');
      await tester.ensureVisible(find.byKey(const Key('feedback_yes')));
      await tester.tap(find.byKey(const Key('feedback_yes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feedback_thanks')), findsOneWidget);
      expect(store.rows['r1']!.feedback, 'correct');
      expect(store.rows['r1']!.isSynced, isFalse);

      // Re-open the entry from scratch: the choice is still shown.
      final saved = store.rows['r1']!;
      await open(tester, saved);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('feedback_yes'))).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('feedback_no'))).selected, isFalse);
    });

    testWidgets('👎 asks what it really was, from this crop\'s diseases only', (tester) async {
      await open(tester, rec('rice_blast'), kb: kbOf([..._std, entry('potato_x', 'potato', 'আলুর রোগ', 'low')]));
      await tester.ensureVisible(find.byKey(const Key('feedback_no')));
      await tester.tap(find.byKey(const Key('feedback_no')));
      await tester.pumpAndSettle();
      expect(find.text('আসল রোগ কী ছিল?'), findsOneWidget);
      expect(find.text('শিথ ব্লাইট'), findsOneWidget);
      expect(find.text('আলুর রোগ'), findsNothing);
      await tester.tap(find.text('শিথ ব্লাইট'));
      await tester.pumpAndSettle();
      expect(store.rows['r1']!.feedback, 'incorrect');
      expect(store.rows['r1']!.feedbackActual, 'rice_sheath');
      expect(find.byKey(const Key('feedback_thanks')), findsOneWidget);
    });

    testWidgets('👎 with "জানি না" or a dismissed picker still records the feedback', (tester) async {
      await open(tester, rec('rice_blast'));
      await tester.ensureVisible(find.byKey(const Key('feedback_no')));
      await tester.tap(find.byKey(const Key('feedback_no')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('জানি না'));
      await tester.pumpAndSettle();
      expect(store.rows['r1']!.feedback, 'incorrect');
      expect(store.rows['r1']!.feedbackActual, isNull);
    });
  });

  group('listen (task 4.4)', () {
    testWidgets('tapping শুনুন reads the KB-built script; pause/resume/stop controls appear', (tester) async {
      await open(tester, rec('rice_blast'));
      await tester.tap(find.byKey(const Key('tts_listen')));
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
      expect(tts.spoken.single, contains('রোগের নাম: ধানের ব্লাস্ট রোগ।'));
      expect(find.byKey(const Key('tts_pause')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tts_pause')));
      await tester.pump();
      expect(find.byKey(const Key('tts_resume')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tts_stop')));
      await tester.pump();
      expect(find.byKey(const Key('tts_listen')), findsOneWidget);
    });

    testWidgets('a missing Bangla voice shows the install guidance dialog', (tester) async {
      await open(tester, rec('rice_blast'));
      tts.installed = false;
      await tester.tap(find.byKey(const Key('tts_listen')));
      await tester.pumpAndSettle();
      expect(find.text('বাংলা কণ্ঠস্বর পাওয়া যাচ্ছে না'), findsOneWidget);
      await tester.tap(find.text('ঠিক আছে'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tts_listen')), findsOneWidget);
      expect(ProviderScope.containerOf(tester.element(find.byKey(const Key('tts_listen')))).read(ttsControllerProvider), TtsStatus.idle);
    });
  });
}
