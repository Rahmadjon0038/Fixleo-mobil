import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';

Widget page(TargetPlatform platform, {bool contrast = false}) => MaterialApp(
  theme: ThemeData(platform: platform),
  home: MediaQuery(
    data: MediaQueryData(highContrast: contrast),
    child: Scaffold(
      body: GlassBackground(
        child: Column(
          children: [
            const GlassContainer(child: Text('Header')),
            GlassContainer.tinted(child: const Text('Send')),
            const GlassContainer.lite(child: Text('Message')),
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showGlassModalBottomSheet<void>(
                  context: context,
                  builder: (_) =>
                      const SizedBox(height: 160, child: Text('Sheet')),
                ),
                child: const Text('Open'),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('iOS retains glass only in chrome, not repeated lite surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(page(TargetPlatform.iOS));
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android chrome and sheets have no backdrop blur', (
    tester,
  ) async {
    await tester.pumpWidget(page(TargetPlatform.android));
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Sheet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('high contrast disables translucent glass on iOS', (
    tester,
  ) async {
    await tester.pumpWidget(page(TargetPlatform.iOS, contrast: true));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Header'), findsOneWidget);
  });
  testWidgets('Android alert stays readable without blur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const Scaffold(
          body: GlassAlertDialog(
            title: Text('Title'),
            content: Text('Message'),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Message'), findsOneWidget);
  });
}
