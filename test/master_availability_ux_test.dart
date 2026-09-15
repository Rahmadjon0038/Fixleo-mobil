import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/master/data/master_availability.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_availability_screen.dart';

class _FakeMasterService extends MasterService {
  List<MasterAvailabilityInterval>? saved;

  @override
  Future<MasterAvailability> availability() async =>
      const MasterAvailability(timezoneOffsetMinutes: 300, intervals: []);

  @override
  Future<MasterAvailability> saveAvailability(
    List<MasterAvailabilityInterval> intervals,
  ) async {
    saved = List.of(intervals);
    return MasterAvailability(
      timezoneOffsetMinutes: 300,
      intervals: List.of(intervals),
    );
  }
}

void main() {
  setUp(() => LocaleController.language.value = AppLanguage.uz);

  testWidgets('workweek template fills five days and exposes save state', (
    tester,
  ) async {
    final service = _FakeMasterService();
    await tester.pumpWidget(
      MaterialApp(home: MasterAvailabilityScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jadval saqlangan'), findsOneWidget);
    await tester.tap(find.text('Dush–Jum 09:00–18:00'));
    await tester.pump();

    expect(find.text('09:00 — 18:00'), findsWidgets);
    expect(find.text('Jadvalni saqlash'), findsOneWidget);

    await tester.tap(find.text('Jadvalni saqlash'));
    await tester.pumpAndSettle();

    expect(service.saved, hasLength(5));
    expect(find.text('Jadval saqlangan'), findsOneWidget);
  });
}
