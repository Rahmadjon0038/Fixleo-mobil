import 'package:fixleo/app/locale/app_locale.dart';

const Set<String> terminalOrderStatuses = {
  'completed',
  'cancelled_by_client',
  'cancelled_by_master',
  'expired',
};

const Set<String> cancelledOrderStatuses = {
  'cancelled_by_client',
  'cancelled_by_master',
};

bool isTerminalOrderStatus(String status) =>
    terminalOrderStatuses.contains(status);

bool isCancelledOrderStatus(String status) =>
    cancelledOrderStatuses.contains(status);

String orderStatusLabel(AppLanguage language, String status) =>
    switch (status) {
      'searching' => tr(
        language,
        'Usta qidirilmoqda',
        'Поиск мастера',
        'Searching for a master',
      ),
      'assigned' => tr(
        language,
        'Usta tayinlandi',
        'Мастер назначен',
        'Master assigned',
      ),
      'on_the_way' => tr(
        language,
        'Usta yo‘lda',
        'Мастер в пути',
        'Master on the way',
      ),
      'arrived' => tr(
        language,
        'Usta yetib keldi',
        'Мастер на месте',
        'Master arrived',
      ),
      'work_done' => tr(
        language,
        'Ish bajarildi',
        'Работа выполнена',
        'Work completed',
      ),
      'completed' => tr(language, 'Yakunlandi', 'Завершён', 'Completed'),
      'disputed' => tr(language, 'Nizo ochilgan', 'Открыт спор', 'Disputed'),
      'cancelled_by_client' => tr(
        language,
        'Mijoz bekor qildi',
        'Отменён клиентом',
        'Cancelled by client',
      ),
      'cancelled_by_master' => tr(
        language,
        'Usta bekor qildi',
        'Отменён мастером',
        'Cancelled by master',
      ),
      'expired' => tr(language, 'Muddati tugadi', 'Срок истёк', 'Expired'),
      _ => tr(language, 'Buyurtma', 'Заказ', 'Order'),
    };
