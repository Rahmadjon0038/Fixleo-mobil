import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/data/master_service_price.dart';
import 'package:fixleo/features/master/presentation/master_service_pricing_screen.dart';

const plumbing = Category(id: 1, name: 'Plumbing');
const electrical = Category(id: 2, name: 'Electrical');
const cleaning = Category(id: 3, name: 'Cleaning');

class PricingService extends MasterService {
  List<int>? savedIds;
  Map<int, int?>? savedPrices;
  @override
  Future<List<MasterServicePrice>> servicePricing() async => const [
    MasterServicePrice(category: plumbing),
    MasterServicePrice(
      category: electrical,
      price: 150000,
      locked: true,
      openOrderCount: 1,
    ),
  ];
  @override
  Future<void> saveServicePricing(
    List<int> categoryIds,
    Map<int, int?> prices,
  ) async {
    savedIds = categoryIds;
    savedPrices = prices;
  }
}

class PricingCategories extends CategoryService {
  @override
  Future<List<Category>> getAll() async => [plumbing, electrical, cleaning];
}

void main() {
  Future<void> openPushedPricing(WidgetTester tester) async {
    LocaleController.language.value = AppLanguage.en;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MasterServicePricingScreen(
                    service: PricingService(),
                    categories: PricingCategories(),
                  ),
                ),
              ),
              child: const Text('Open pricing'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open pricing'));
    await tester.pumpAndSettle();
  }

  testWidgets('system back returns from unchanged pricing to previous route', (
    tester,
  ) async {
    await openPushedPricing(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open pricing'), findsOneWidget);
    expect(find.byType(MasterServicePricingScreen), findsNothing);
  });

  testWidgets(
    'system back confirms unsaved prices and preserves edits on Stay',
    (tester) async {
      await openPushedPricing(tester);
      await tester.enterText(find.byType(TextFormField).first, '120000');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('120 000'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Open pricing'), findsOneWidget);
      expect(find.byType(MasterServicePricingScreen), findsNothing);
    },
  );

  testWidgets(
    'fits a narrow screen and keeps Save above the keyboard in every language',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      for (final language in AppLanguage.values) {
        LocaleController.language.value = language;
        await tester.pumpWidget(
          MaterialApp(
            home: MasterServicePricingScreen(
              key: ValueKey(language),
              service: PricingService(),
              categories: PricingCategories(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final save = find.byType(FilledButton).last;
        expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(420));
      }
    },
  );

  Future<PricingService> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    LocaleController.language.value = AppLanguage.en;
    final service = PricingService();
    await tester.pumpWidget(
      MaterialApp(
        home: MasterServicePricingScreen(
          service: service,
          categories: PricingCategories(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets(
    'shows readiness, keeps locked service disabled, saves all prices once',
    (tester) async {
      final service = await open(tester);
      expect(find.text('1 / 2 services ready'), findsOneWidget);
      final fields = find.byType(TextFormField);
      expect(tester.widget<TextFormField>(fields.at(1)).enabled, isFalse);
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        '150 000',
      );
      await tester.enterText(fields.first, '120000');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        '120 000',
      );
      expect(find.text('2 / 2 services ready'), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(service.savedIds, [1, 2]);
      expect(service.savedPrices, {1: 120000});
    },
  );

  testWidgets('missing filter does not remove a row while typing', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Missing prices'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.pump();
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('can add a service and save it without a price as paused', (
    tester,
  ) async {
    final service = await open(tester);
    await tester.tap(find.text('Add services'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(service.savedIds, [1, 2, 3]);
    expect(service.savedPrices, {1: null, 3: null});
  });

  testWidgets(
    'rejects invalid prices even if their field is hidden by add tab',
    (tester) async {
      final service = await open(tester);
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.text('Add services'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(service.savedIds, isNull);
      expect(
        find.text('Prices must be between 1 and 2,000,000,000 UZS'),
        findsOneWidget,
      );
    },
  );
}
