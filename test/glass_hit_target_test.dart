import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform_views'),
          (call) async => null,
        );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform_views'),
          null,
        );
  });
  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets(
    'native primary button fires once across left, label, icon and right',
    (tester) async {
      var taps = 0;
      await mount(
        tester,
        SizedBox(
          width: 300,
          child: GlassButton(
            label: 'Save',
            icon: Icons.check,
            onPressed: () => taps++,
          ),
        ),
      );
      final rect = tester.getRect(find.byType(GlassButton));
      for (final point in [
        rect.centerLeft + const Offset(8, 0),
        tester.getCenter(find.text('Save')),
        tester.getCenter(find.byIcon(Icons.check)),
        rect.centerRight - const Offset(8, 0),
      ]) {
        await tester.tapAt(point);
        await tester.pumpAndSettle();
      }
      expect(taps, 4);
      expect(find.byType(UiKitView), findsOneWidget);
      // All UIKit views are decorative: native channel events cannot double fire.
      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      expect((view.creationParams as Map)['interactive'], false);
      await done(tester);
    },
  );
  testWidgets('native icon button padding and icon share the same action', (
    tester,
  ) async {
    var taps = 0;
    await mount(
      tester,
      GlassIconButton(
        size: 56,
        onTap: () => taps++,
        child: const Icon(Icons.arrow_back),
      ),
    );
    final rect = tester.getRect(find.byType(GlassIconButton));
    await tester.tapAt(rect.centerLeft + const Offset(5, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byIcon(Icons.arrow_back)));
    await tester.pumpAndSettle();
    await tester.tapAt(rect.centerRight - const Offset(5, 0));
    expect(taps, 3);
    await done(tester);
  });
  testWidgets('disabled native button never handles taps', (tester) async {
    await mount(
      tester,
      const SizedBox(
        width: 300,
        child: GlassButton(label: 'Disabled', onPressed: null),
      ),
    );
    await tester.tap(find.byType(GlassButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<UiKitView>(find.byType(UiKitView)).creationParams,
      containsPair('interactive', false),
    );
    expect(tester.takeException(), isNull);
    await done(tester);
  });
  testWidgets(
    'legacy gestures hit the full padding of both native surface types',
    (tester) async {
      var taps = 0;
      for (final surface in <Widget>[
        const GlassContainer(
          width: 240,
          height: 64,
          padding: EdgeInsets.all(16),
          alignment: Alignment.center,
          child: Text('Label'),
        ),
        LiquidSurface(
          width: 240,
          height: 64,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text('Label'),
        ),
      ]) {
        await mount(
          tester,
          GestureDetector(
            key: const ValueKey('target'),
            onTap: () => taps++,
            child: surface,
          ),
        );
        final rect = tester.getRect(find.byKey(const ValueKey('target')));
        await tester.tapAt(rect.centerLeft + const Offset(5, 0));
        await tester.tapAt(rect.centerRight - const Offset(5, 0));
      }
      expect(taps, 4);
      await done(tester);
    },
  );
  testWidgets(
    'dragging a scroll view from a glass button does not activate it',
    (tester) async {
      var taps = 0;
      await mount(
        tester,
        SizedBox(
          width: 300,
          height: 240,
          child: ListView(
            children: [
              GlassButton(label: 'Action', onPressed: () => taps++),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.drag(find.byType(GlassButton), const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(taps, 0);
      await done(tester);
    },
  );
}
