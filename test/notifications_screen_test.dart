import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/notifications/data/notification_service.dart';
import 'package:fixleo/features/notifications/presentation/notifications_screen.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(kind: 'client');

  int listCalls = 0;
  int markReadCalls = 0;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    listCalls++;
    return [
      AppNotification(
        id: 1,
        type: 'offer_received',
        title: 'New offer',
        body: 'A master sent a price offer',
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      AppNotification(
        id: 2,
        type: 'chat_message',
        title: 'New message',
        body: 'Your master wrote to you',
        readAt: DateTime.now().subtract(const Duration(minutes: 5)),
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
  }

  @override
  Future<void> markAllRead() async {
    markReadCalls++;
  }
}

void main() {
  testWidgets(
    'notification inbox renders API items and acknowledges unread rows',
    (tester) async {
      LocaleController.language.value = AppLanguage.en;
      addTearDown(() => LocaleController.language.value = AppLanguage.ru);
      final service = _FakeNotificationService();

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(kind: 'client', service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New offer'), findsOneWidget);
      expect(find.text('A master sent a price offer'), findsOneWidget);
      expect(find.text('New message'), findsOneWidget);
      expect(service.listCalls, 1);
      expect(service.markReadCalls, 1);
    },
  );
}
