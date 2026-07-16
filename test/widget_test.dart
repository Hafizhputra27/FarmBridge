import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmbridge/main.dart';

void main() {
  testWidgets('App boots with role picker screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FarmBridgeApp()),
    );

    expect(find.text('FarmBridge'), findsOneWidget);
    expect(find.text('Pilih peran Anda'), findsOneWidget);
  });
}
