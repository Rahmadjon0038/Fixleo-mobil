import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/app.dart';

void main() {
  testWidgets('shows hello fixleo on start', (WidgetTester tester) async {
    await tester.pumpWidget(const FixleoApp());

    expect(find.text('Hello Fixleo'), findsOneWidget);
  });
}
