import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/features/master/data/master_availability.dart';
import 'package:fixleo/features/request/data/order_models.dart';

void main() {
  test('master recurring availability keeps multiple ranges per day', () {
    final availability = MasterAvailability.fromJson({
      'timezoneOffsetMinutes': 300,
      'intervals': [
        {'weekday': 1, 'startMinute': 540, 'endMinute': 720},
        {'weekday': 1, 'startMinute': 840, 'endMinute': 1080},
      ],
    });

    expect(availability.timezoneOffsetMinutes, 300);
    expect(availability.intervals, hasLength(2));
    expect(availability.intervals.first.toJson(), {
      'weekday': 1,
      'startMinute': 540,
      'endMinute': 720,
    });
  });

  test('scheduled candidate exposes booking price and trust signals', () {
    final master = ScheduledMasterOption.fromJson({
      'numericId': 9,
      'name': 'Akmal',
      'ratingAvg': 4.9,
      'ratingCount': 17,
      'completedOrders': 31,
      'distanceKm': 2.45,
      'price': 150000,
    });

    expect(master.numericId, 9);
    expect(master.price, 150000);
    expect(master.ratingAvg, 4.9);
    expect(master.ratingCount, 17);
    expect(master.completedOrders, 31);
    expect(master.distanceKm, 2.45);
  });

  test('scheduled order detail keeps its exact appointment instant', () {
    final order = OrderDetail.fromJson({
      'id': 22,
      'title': 'Bog‘ ishlari',
      'description': 'Test',
      'status': 'searching',
      'addressText': 'Toshkent',
      'timing': 'scheduled',
      'scheduledDate': '2026-09-14',
      'scheduledAt': '2026-09-14T01:30:00.000Z',
    });

    expect(order.scheduledAt, DateTime.utc(2026, 9, 14, 1, 30));
  });
}
