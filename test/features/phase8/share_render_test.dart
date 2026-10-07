import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/core/l10n/gen/app_localizations.dart';
import 'package:mather_sathi/core/l10n/gen/app_localizations_bn.dart';
import 'package:mather_sathi/features/share/share_card.dart';
import 'package:mather_sathi/features/share/share_content.dart';
import 'package:mather_sathi/features/share/share_service.dart';

void main() {
  const content = ShareContent(
    title: 'ধানের ব্লাস্ট রোগ', action: 'আক্রান্ত পাতা তুলে ফেলুন', medicine: 'ওষুধ ক — ২ গ্রাম', tagline: 'কৃষি সহায় অ্যাপ থেকে পাঠানো', disclaimer: 'এআই-ভিত্তিক পরামর্শ',
  );

  testWidgets('the card widget lays out at its fixed width with all the lines', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ShareCard(content: content, labels: AppLocalizationsBn())))));
    expect(tester.getSize(find.byKey(const Key('share_card'))).width, ShareCard.width);
    expect(find.textContaining('ধানের ব্লাস্ট রোগ'), findsOneWidget);
    expect(find.text('ওষুধ ক — ২ গ্রাম'), findsOneWidget);
  });

  testWidgets('the off-screen renderer produces a PNG', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final png = await tester.runAsync(() => ScreenshotCardRenderer().render(ctx, content, AppLocalizationsBn() as AppLocalizations));
    expect(png, isNotNull, reason: 'rendering failed and fell back to text-only');
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
  });
}
