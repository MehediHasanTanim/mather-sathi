import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/capture/data/image_analysis.dart';
import 'package:mather_sathi/features/capture/data/image_prep_service.dart';
import 'package:mather_sathi/features/capture/providers/capture_provider.dart';
import 'package:mather_sathi/features/diagnosis/data/cloud_client.dart';
import 'package:mather_sathi/features/diagnosis/diagnosis_service.dart';
import 'package:mather_sathi/features/diagnosis/providers/diagnosis_providers.dart';
import 'package:mather_sathi/features/history/providers/history_provider.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/kb/kb_provider.dart';
import 'package:mather_sathi/providers/core_providers.dart';

import '../../support/capture_fakes.dart';
import '../../support/diagnosis_fakes.dart';
import '../../support/phase4_fakes.dart';
import '../../support/pump_app.dart';

final _jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

class _Kb extends KbNotifier {
  @override
  Future<KnowledgeBase> build() async => testKb();
}

// ignore: invalid_use_of_protected_member
FirebaseFunctionsException fnError(String code) => FirebaseFunctionsException(message: 'm', code: code);

late InMemoryHistoryStore store;
late FakePhotoStore photos;

/// Home → gallery photo → preview → Analyze, with the cloud faked.
Future<void> toAnalyze(WidgetTester tester, CloudDiagnosisClient cloud, {bool other = false}) async {
  store = InMemoryHistoryStore();
  photos = FakePhotoStore();
  await pumpApp(tester, saved: doneProfile, overrides: [
    photoPickerProvider.overrideWithValue(FakePhotoPicker(file: File('p.jpg'))),
    pendingCaptureStoreProvider.overrideWithValue(FakePendingStore()),
    imagePrepServiceProvider.overrideWithValue(
        FakePrepService(PreparedImage.ready(_jpeg, const ImageStats(meanLuma: 100, laplacianVar: 500)))),
    kbProvider.overrideWith(() => _Kb()),
    historyDaoProvider.overrideWithValue(store),
    photoStoreProvider.overrideWithValue(photos),
    diagnosisServiceProvider.overrideWithValue(DiagnosisService(
      cloud: cloud, local: const NoLocalClassifier(), connectivity: FakeConnectivity(true),
      auth: FakeAuth(), kb: testKb, flags: () => RemoteFlags.defaults,
    )),
  ]);
  if (other) {
    await tester.tap(find.byKey(const Key('crop_other')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ধনেপাতা');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ঠিক আছে'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('pick_gallery')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('analyze')));
}

String message(WidgetTester t) => t.widget<Text>(find.byKey(const Key('result_message'))).data!;

void main() {
  testWidgets('M1: photo → analyzing → saved → result rendered from the KB; Back returns home', (tester) async {
    await toAnalyze(tester, fakeCloud(response: cloudClassified('rice_blast', confidence: 'medium')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('disease_name'))).data, 'ধানের ব্লাস্ট রোগ');
    expect(store.rows, hasLength(1));
    expect(photos.files.values.single, _jpeg, reason: 'the prepared photo is what is stored');
    expect(store.rows.values.single.diseaseNameBn, 'ধানের ব্লাস্ট রোগ');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('take_photo')), findsOneWidget, reason: 'back from a result goes home, not to a stale preview');
    final c = ProviderScope.containerOf(tester.element(find.byKey(const Key('take_photo'))));
    expect(c.read(captureProvider).prepared, isNull);
    expect(c.read(diagnosisFlowProvider), isA<FlowIdle>());
  });

  testWidgets('other crop ends in the general-advice result', (tester) async {
    await toAnalyze(tester, other: true, fakeCloud(response: {
      'mode': 'general', 'summary_bn': 'পাতায় দাগ আছে।', 'prevention_bn': ['ক্ষেত পরিষ্কার রাখুন'], 'image_issue': 'none', 'see_expert': true,
    }));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('general_summary'))).data, 'পাতায় দাগ আছে।');
    expect(store.rows.values.single.cropLabel, 'ধনেপাতা');
  });

  testWidgets('a progress screen with a cancel button shows while the cloud call is running; cancel is safe', (tester) async {
    final gate = Completer<Map<String, dynamic>>();
    await toAnalyze(tester, CloudDiagnosisClient((_) => gate.future));
    await tester.pump();
    expect(find.byKey(const Key('analyzing_text')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('analyzing_text'))).data, 'বিশ্লেষণ করা হচ্ছে…');

    await tester.tap(find.byKey(const Key('cancel_analysis')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('analyze')), findsOneWidget, reason: 'back on the preview');
    gate.complete(cloudClassified('rice_blast'));
    await tester.pumpAndSettle();
    expect(store.rows, isEmpty, reason: 'a cancelled run saves nothing');
    expect(find.byKey(const Key('disease_name')), findsNothing);
  });

  testWidgets('the system Back button during analysis cancels too', (tester) async {
    final gate = Completer<Map<String, dynamic>>();
    await toAnalyze(tester, CloudDiagnosisClient((_) => gate.future));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    gate.complete(cloudClassified('rice_blast'));
    await tester.pumpAndSettle();
    expect(store.rows, isEmpty);
    final c = ProviderScope.containerOf(tester.element(find.byKey(const Key('analyze'))));
    expect(c.read(diagnosisFlowProvider), isA<FlowIdle>());
  });

  testWidgets('a bad photo (unknown + issue) shows the tip with retake, nothing saved', (tester) async {
    await toAnalyze(tester, fakeCloud(response: cloudClassified('unknown', issue: 'too_dark', confidence: 'low')));
    await tester.pumpAndSettle();
    expect(message(tester), 'আলো কম — আলোতে গিয়ে আবার ছবি তুলুন');
    expect(find.byKey(const Key('change_crop')), findsNothing);
    expect(store.rows, isEmpty);
    await tester.tap(find.byKey(const Key('retake_action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('analyze')), findsOneWidget);
  });

  testWidgets('wrong crop offers to change the crop', (tester) async {
    await toAnalyze(tester, fakeCloud(response: cloudClassified('unknown', issue: 'wrong_crop', confidence: 'low')));
    await tester.pumpAndSettle();
    expect(message(tester), 'এটি ধান বলে মনে হচ্ছে না — ফসল ঠিক আছে?');
    await tester.tap(find.byKey(const Key('change_crop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crop_rice')), findsOneWidget);
  });

  testWidgets('a timeout offers retry, and retry works', (tester) async {
    var calls = 0;
    await toAnalyze(tester, CloudDiagnosisClient((_) async {
      if (++calls == 1) throw fnError('deadline-exceeded');
      return cloudClassified('rice_blast');
    }));
    await tester.pumpAndSettle();
    expect(message(tester), 'বিশ্লেষণ করা যায়নি। আবার চেষ্টা করুন');
    await tester.tap(find.byKey(const Key('retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('disease_name')), findsOneWidget);
    expect(store.rows, hasLength(1));
  });

  testWidgets('daily cap and rejected service show their message without a retry loop', (tester) async {
    await toAnalyze(tester, fakeCloud(throws: fnError('resource-exhausted')));
    await tester.pumpAndSettle();
    expect(message(tester), 'আজকের সীমা শেষ — আগামীকাল আবার চেষ্টা করুন');
    expect(find.byKey(const Key('retry')), findsNothing);
    expect(find.byKey(const Key('failure_back')), findsOneWidget);
  });

  testWidgets('service rejected: generic message, no retry', (tester) async {
    await toAnalyze(tester, fakeCloud(throws: fnError('unauthenticated')));
    await tester.pumpAndSettle();
    expect(message(tester), 'বিশ্লেষণ করা যায়নি। আবার চেষ্টা করুন');
    expect(find.byKey(const Key('retry')), findsNothing);
  });
}
