import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/request/data/new_order_draft.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';
import 'package:fixleo/features/request/presentation/review_request_screen.dart';
import 'package:fixleo/features/request/presentation/time_urgency_screen.dart';

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
      MaterialApp(home: TimeUrgencyScreen(draft: NewOrderDraft())),
    );

    expect(find.text('Bugungi vaqtlar'), findsNothing);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
  });

  testWidgets('today requires only a time slot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TimeUrgencyScreen(draft: NewOrderDraft())),
    );

    await tester.tap(find.text('Bugun').first);
    await tester.pump();
    expect(find.text('Bugungi vaqtlar'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);

    await tester.tap(find.text('Davom etish'));
    await tester.pump();
    expect(find.text('Vaqtni tanlang'), findsOneWidget);
  });

  testWidgets('later requires a date before showing slots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TimeUrgencyScreen(draft: NewOrderDraft())),
    );

    await tester.tap(find.text('Ertaga yoki keyinroq').first);
    await tester.pump();
    expect(find.text('Sanani tanlang'), findsOneWidget);
    expect(find.text('Tanlangan kun vaqtlari'), findsNothing);
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
