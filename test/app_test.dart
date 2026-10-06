import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_sahay/app.dart';

void main() {
  testWidgets('app boots and shows the Bangla app name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KrishiApp()));
    expect(find.text('কৃষি সহায়'), findsOneWidget);
  });
}
