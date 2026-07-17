import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/app.dart';
import 'package:fixleo/features/splash/presentation/splash_screen.dart';

void main() {
  testWidgets('shows the splash screen on start', (WidgetTester tester) async {
    await tester.pumpWidget(const FixleoApp());

    expect(find.byType(SplashScreen), findsOneWidget);

    // Let the splash timer finish so the test ends with no pending timers.
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
