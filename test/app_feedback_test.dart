import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    bool accessible = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            accessibleNavigation: accessible,
            textScaler: TextScaler.linear(textScale),
          ),
          child: AppFeedbackHost(child: child!),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) => SizedBox(
                  height: 250,
                  child: Column(
                    children: [
                      const Text('Payment sheet'),
                      TextButton(
                        onPressed: () =>
                            AppFeedback.of(sheetContext).showSnackBar(
                              const SnackBar(content: Text('Payment error')),
                            ),
                        child: const Text('Fail'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('feedback is visible and interactive above a bottom sheet', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fail'));
    await tester.pumpAndSettle();
    expect(find.text('Payment error').hitTestable(), findsOneWidget);
    expect(find.text('Payment sheet'), findsOneWidget);
    // The close control would be intercepted by the modal barrier if layering
    // were wrong. Closing feedback must not dismiss the payment sheet.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Payment error'), findsNothing);
    expect(find.text('Payment sheet'), findsOneWidget);
  });

  testWidgets('new modal routes cannot cover an existing message', (
    tester,
  ) async {
    await mount(tester);
    final context = tester.element(find.text('Open sheet'));
    AppFeedback.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved')));
    await tester.pumpAndSettle();
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(title: Text('Dialog')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Dialog'), findsOneWidget);
  });

  testWidgets('replacement cancels the old timer and preserves the action', (
    tester,
  ) async {
    await mount(tester);
    final messenger = AppFeedback.of(tester.element(find.text('Open sheet')));
    messenger.showSnackBar(
      const SnackBar(content: Text('Old'), duration: Duration(seconds: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    var actions = 0;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Latest'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Retry', onPressed: () => actions++),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Old'), findsNothing);
    expect(find.text('Latest'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Latest'), findsNothing);
  });

  testWidgets('screen-reader actions do not time out', (tester) async {
    await mount(tester, accessible: true);
    AppFeedback.of(tester.element(find.text('Open sheet'))).showSnackBar(
      SnackBar(
        content: const Text('Permission required'),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(label: 'Settings', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Permission required'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long text with keyboard and large font is scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await mount(tester, textScale: 2);
      final context = tester.element(find.text('Open sheet'));
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Long error message. ' * 50)));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
