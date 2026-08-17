import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';
import 'package:fixleo/features/notifications/data/notification_service.dart';
import 'package:fixleo/features/request/data/chat_service.dart' as chat;
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/my_orders_screen.dart';

class _FakeHomeOrderService extends OrderService {
  @override
  Future<List<ClientAddress>> addresses() async => const [];

  @override
  Future<List<OrderSummary>> list({String? status}) async {
    if (status != 'active') return const [];
    return const [
      OrderSummary(id: 11, title: 'First job', status: 'assigned'),
      OrderSummary(id: 12, title: 'Second job', status: 'searching'),
    ];
  }
}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(kind: 'client');

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async =>
      const [];
}

class _FakeCategoryService extends CategoryService {
  @override
  Future<List<Category>> getAll() async => const [];
}

class _FakeChatService extends chat.ChatService {
  _FakeChatService() : super(kind: 'client');

  @override
  Future<List<chat.Conversation>> conversations() async => const [
    chat.Conversation(
      id: 1,
      orderId: 11,
      orderTitle: 'First job',
      unreadCount: 2,
    ),
    chat.Conversation(
      id: 2,
      orderId: 12,
      orderTitle: 'Second job',
      unreadCount: 3,
    ),
  ];
}

void main() {
  testWidgets('home shows active count and View opens the Active orders tab', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          orderService: _FakeHomeOrderService(),
          notificationService: _FakeNotificationService(),
          categoryService: _FakeCategoryService(),
          chatService: _FakeChatService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('You have 2 active orders'), findsOneWidget);
    expect(find.text('Active order · First job'), findsOneWidget);
    expect(
      tester
          .widget<LiquidGlassNavBar>(find.byType(LiquidGlassNavBar))
          .items[2]
          .badgeCount,
      5,
    );
    await tester.tap(find.text('Chats'));
    await tester.pump();
    // One screen title plus the bottom-tab label; no duplicate screen title.
    expect(find.text('Chats'), findsNWidgets(2));
    await tester.tap(find.text('Home'));
    await tester.pump();

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    final orders = tester.widget<MyOrdersScreen>(find.byType(MyOrdersScreen));
    expect(orders.initialTab, 0);
    expect(orders.embedded, isTrue);
    expect(
      tester
          .widget<LiquidGlassNavBar>(find.byType(LiquidGlassNavBar))
          .currentIndex,
      1,
    );
  });

  testWidgets('client bottom tabs keep the selected orders segment', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          orderService: _FakeHomeOrderService(),
          notificationService: _FakeNotificationService(),
          categoryService: _FakeCategoryService(),
          chatService: _FakeChatService(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Orders'));
    await tester.pump();
    await tester.tap(find.text('Completed'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Completed')).style?.fontWeight,
      FontWeight.w600,
    );

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.tap(find.text('Orders'));
    await tester.pump();

    expect(
      tester
          .widget<LiquidGlassNavBar>(find.byType(LiquidGlassNavBar))
          .currentIndex,
      1,
    );
    expect(
      tester.widget<Text>(find.text('Completed')).style?.fontWeight,
      FontWeight.w600,
    );
  });
}
