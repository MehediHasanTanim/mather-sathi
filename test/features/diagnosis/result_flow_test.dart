import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/capture/data/image_analysis.dart';
import 'package:mather_sathi/features/capture/data/image_prep_service.dart';
import 'package:mather_sathi/features/capture/providers/capture_provider.dart';
import 'package:mather_sathi/features/diagnosis/diagnosis_service.dart';
import 'package:mather_sathi/features/diagnosis/providers/diagnosis_providers.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';
import 'package:mather_sathi/features/kb/kb_provider.dart';

import '../../support/capture_fakes.dart';
import '../../support/diagnosis_fakes.dart';
import '../../support/pump_app.dart';

final _jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

class _FakeKb extends KbNotifier {
  _FakeKb(this.kb);
  final KnowledgeBase kb;
  @override
  Future<KnowledgeBase> build() async => kb;
}

// ignore: invalid_use_of_protected_member
FirebaseFunctionsException fnError(String code) => FirebaseFunctionsException(message: 'm', code: code);

Future<void> analyze(WidgetTester tester, {required Map<String, dynamic>? response, Object? throws, bool drafts = false, bool other = false}) async {
  final service = DiagnosisService(
    cloud: fakeCloud(response: response, throws: throws),
    local: const NoLocalClassifier(), connectivity: FakeConnectivity(true), auth: FakeAuth(),
    kb: () => testKb(drafts: drafts), flags: () => RemoteFlags.defaults,
  );
  await pumpApp(tester, saved: doneProfile, overrides: [
    photoPickerProvider.overrideWithValue(FakePhotoPicker(file: File('p.jpg'))),
    pendingCaptureStoreProvider.overrideWithValue(FakePendingStore()),
    imagePrepServiceProvider.overrideWithValue(FakePrepService(
        PreparedImage.ready(_jpeg, const ImageStats(meanLuma: 100, laplacianVar: 500)))),
    kbProvider.overrideWith(() => _FakeKb(testKb(drafts: drafts))),
    diagnosisServiceProvider.overrideWithValue(service),
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('M1: a photo becomes a disease name rendered from the KB', (tester) async {
    await analyze(tester, response: cloudClassified('rice_blast', confidence: 'medium'));
    expect(tester.widget<Text>(find.byKey(const Key('disease_name'))).data, 'ধানের ব্লাস্ট রোগ');
    expect(find.text('সম্ভাব্য রোগ ⚠️ — বিশেষজ্ঞকে দেখান'), findsOneWidget);
    expect(find.text('• লক্ষণ ১'), findsOneWidget);
    expect(find.byKey(const Key('draft_banner')), findsNothing);
  });

  testWidgets('a KB with draft entries shows the not-reviewed banner', (tester) async {
    await analyze(tester, response: cloudClassified('rice_blast'), drafts: true);
    expect(find.byKey(const Key('draft_banner')), findsOneWidget);
  });

  testWidgets('healthy and unknown results have their own copy', (tester) async {
    await analyze(tester, response: cloudClassified('healthy'));
    expect(find.text('আপনার ফসলে কোনো পরিচিত রোগ দেখা যায়নি 🌿'), findsOneWidget);
  });

  testWidgets('unknown + bad photo shows the retake tip', (tester) async {
    await analyze(tester, response: cloudClassified('unknown', issue: 'too_dark', confidence: 'low'));
    expect(tester.widget<Text>(find.byKey(const Key('result_message'))).data, 'আলো কম — আলোতে গিয়ে আবার ছবি তুলুন');
  });

  testWidgets('daily cap shows its Bangla message', (tester) async {
    await analyze(tester, response: null, throws: fnError('resource-exhausted'));
    expect(tester.widget<Text>(find.byKey(const Key('result_message'))).data, 'আজকের সীমা শেষ — আগামীকাল আবার চেষ্টা করুন');
  });

  testWidgets('a timeout shows the generic retry message', (tester) async {
    await analyze(tester, response: null, throws: fnError('deadline-exceeded'));
    expect(tester.widget<Text>(find.byKey(const Key('result_message'))).data, 'বিশ্লেষণ করা যায়নি। আবার চেষ্টা করুন');
  });

  testWidgets('other-crop advice shows the summary and the expert prompt, with no disease card', (tester) async {
    await analyze(tester, other: true, response: {
      'mode': 'general', 'summary_bn': 'পাতায় দাগ আছে।', 'prevention_bn': ['ক্ষেত পরিষ্কার রাখুন'], 'image_issue': 'none', 'see_expert': true,
    });
    expect(tester.widget<Text>(find.byKey(const Key('general_summary'))).data, 'পাতায় দাগ আছে।');
    expect(find.text('• ক্ষেত পরিষ্কার রাখুন'), findsOneWidget);
    expect(find.text('👨‍⚕️ কৃষি কর্মকর্তার পরামর্শ নিন'), findsOneWidget);
    expect(find.byKey(const Key('disease_name')), findsNothing);
  });
}
