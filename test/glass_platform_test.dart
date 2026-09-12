import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';

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
  testWidgets('legacy logo pills, lite cards and actions create native glass', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter/platform_views'),
      (call) async => null,
    );
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform_views'),
        null,
      );
    });
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LiquidSurface(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('FixLeo'),
                ),
              ),
              const GlassContainer.lite(child: Text('Chatlar')),
              LiquidActionButton.filled(
                onPressed: () => taps++,
                child: const Text('Save'),
              ),
              LiquidIconControl(
                child: IconButton(
                  onPressed: () => taps++,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsNWidgets(4));
    await tester.tap(find.text('Save'));
    await tester.tap(find.byIcon(Icons.close));
    expect(taps, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android adapter preserves Material icon-button sizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              LiquidActionButton.filledIcon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(FilledButton).at(0)),
      tester.getSize(find.byType(FilledButton).at(1)),
    );
    expect(find.byType(UiKitView), findsNothing);
  });

  testWidgets(
    'actual iOS selects UIKit glass, not a backdrop-filter imitation',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final created = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform_views'),
        (call) async {
          if (call.method == 'create') {
            created.add((call.arguments as Map)['viewType'] as String);
          }
          return null;
        },
      );
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/platform_views'),
          null,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const Scaffold(
            body: GlassContainer(child: SizedBox(width: 180, height: 80)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(created, ['real_liquid_glass/glass_view']);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Android header and nav keep their lightweight non-UIKit surface',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: BrandedScaffold(
            title: 'Wallet',
            showBack: true,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: LiquidGlassNavBar(
                items: const [
                  LiquidGlassNavItem('Home', 'assets/logo.svg'),
                  LiquidGlassNavItem('Profile', 'assets/logo.svg'),
                ],
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('iOS theme on a non-iOS host uses the Flutter fallback', (
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
