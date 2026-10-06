import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/app.dart';
import 'package:mather_sathi/core/firebase/anonymous_auth.dart';

void main() {
  testWidgets('app shows the Bangla name and the anonymous uid', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [anonymousUidProvider.overrideWith((ref) async => 'test-uid')],
      child: const KrishiApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('কৃষি সহায়'), findsOneWidget);
    expect(find.text('uid: test-uid'), findsOneWidget);
  });
}
