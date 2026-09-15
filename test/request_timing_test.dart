import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/request/data/new_order_draft.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';
import 'package:fixleo/features/request/presentation/review_request_screen.dart';
import 'package:fixleo/features/request/presentation/time_urgency_screen.dart';

class _FakeOrderService extends OrderService {
  _FakeOrderService({this.asapAvailable = true});

  final bool asapAvailable;

  @override
  Future<OrderSlots> slots({String? date}) async => OrderSlots(
    date: date ?? '2026-08-28',
    asapAvailable: asapAvailable,
    slots: const [
      OrderSlot(slot: 's10_12', label: '10:00–12:00', available: true),
      OrderSlot(slot: 's12_15', label: '12:00–15:00', available: true),
      OrderSlot(slot: 's15_18', label: '15:00–18:00', available: true),
      OrderSlot(slot: 's18_21', label: '18:00–21:00', available: true),
    ],
  );
}

void main() {
  setUp(() => LocaleController.language.value = AppLanguage.uz);

  test('urgent timing label never needs a slot', () {
    expect(
      orderTimingLabel(AppLanguage.uz, timing: 'asap'),
      'Shoshilinch — hozir',
    );
  });

  testWidgets('urgent hides time selection', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimeUrgencyScreen(
          draft: NewOrderDraft(),
          orderService: _FakeOrderService(),
        ),
      ),
    );

    expect(find.text('Bugungi vaqtlar'), findsNothing);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
  });

  testWidgets('scheduled mode asks for one exact date and time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimeUrgencyScreen(
          draft: NewOrderDraft(),
          orderService: _FakeOrderService(),
        ),
      ),
    );

    await tester.tap(find.text('Rejalashtirish').first);
    await tester.pump();
    expect(find.text('Kelish vaqti'), findsOneWidget);
    expect(find.text('Sana va vaqtni tanlang'), findsNWidgets(2));
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

    final continueButton = tester.widget<GlassButton>(
      find.byType(GlassButton).last,
    );
    expect(continueButton.label, 'Sana va vaqtni tanlang');
    expect(continueButton.onPressed, isNull);
  });

  testWidgets('timing screen offers only urgent and scheduled modes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimeUrgencyScreen(
          draft: NewOrderDraft(),
          orderService: _FakeOrderService(),
        ),
      ),
    );

    expect(find.text('Shoshilinch'), findsOneWidget);
    expect(find.text('Rejalashtirish'), findsOneWidget);
    expect(find.text('Bugun'), findsNothing);
    expect(find.text('Ertaga yoki keyinroq'), findsNothing);
  });

  testWidgets('unavailable urgent mode automatically moves to scheduling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimeUrgencyScreen(
          draft: NewOrderDraft(),
          orderService: _FakeOrderService(asapAvailable: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hozir xizmat vaqti emas'), findsOneWidget);
    expect(find.text('Sana va vaqtni tanlang'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('review shows selected local photo thumbnails', (tester) async {
    final draft = NewOrderDraft(categoryId: 1, categoryName: 'Elektrika')
      ..description = 'Yetarlicha uzun test tavsifi'
      ..latitude = 41.311081
      ..longitude = 69.279737
      ..addressText = 'Test manzil'
      ..photoKeys.add('staged/test.jpg')
      ..photoPaths.add(File('assets/onboarding_intro.png').absolute.path);

    await tester.pumpWidget(
      MaterialApp(home: ReviewRequestScreen(draft: draft)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 ta rasm'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
