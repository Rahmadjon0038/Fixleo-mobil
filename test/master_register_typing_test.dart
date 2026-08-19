import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_register_screen.dart';

void main() {
  testWidgets('name, city and experience fields accept input and enable the button',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MasterRegisterScreen()));

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'Test Master');
    await tester.pump();
    expect(find.text('Test Master'), findsOneWidget);

    await tester.enterText(fields.at(1), 'Toshkent');
    await tester.enterText(fields.at(2), '5');
    await tester.pump();

    final button = tester.widget<PrimaryButton>(
      find.byType(PrimaryButton).first,
    );
    expect(button.onPressed, isNotNull,
        reason: 'Davom etish should be enabled when all fields are filled');
  });
}
