import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/request/data/order_status.dart';

void main() {
  test('terminal and cancelled status sets include both cancellation actors', () {
    expect(isTerminalOrderStatus('cancelled_by_client'), isTrue);
    expect(isTerminalOrderStatus('cancelled_by_master'), isTrue);
    expect(isCancelledOrderStatus('cancelled_by_client'), isTrue);
    expect(isCancelledOrderStatus('cancelled_by_master'), isTrue);
    expect(isCancelledOrderStatus('completed'), isFalse);
  });

  test('cancellation actor labels are localized independently', () {
    expect(
      orderStatusLabel(AppLanguage.uz, 'cancelled_by_client'),
      'Mijoz bekor qildi',
    );
    expect(
      orderStatusLabel(AppLanguage.ru, 'cancelled_by_master'),
      'Отменён мастером',
    );
    expect(
      orderStatusLabel(AppLanguage.en, 'cancelled_by_master'),
      'Cancelled by master',
    );
  });
}
