import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
  int addressesCalls = 0;
  int listCalls = 0;

  @override
  Future<List<ClientAddress>> addresses() async {
    addressesCalls++;
    return const [];
  }

  @override
  Future<List<OrderSummary>> list({String? status}) async {
    listCalls++;
    if (status != 'active') return const [];
    return const [
      OrderSummary(id: 11, title: 'First job', status: 'assigned'),
      OrderSummary(id: 12, title: 'Second job', status: 'searching'),
    ];
  }
}

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(kind: 'client');

  int listCalls = 0;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    listCalls++;
    return const [];
  }
}

class _FakeCategoryService extends CategoryService {
  int getGroupsCalls = 0;

  @override
  Future<List<CategoryGroup>> getGroups() async {
    getGroupsCalls++;
    return const [];
  }
}

class _FakeCatalogCategoryService extends CategoryService {
  @override
  Future<List<CategoryGroup>> getGroups() async => const [
    CategoryGroup(
      id: 1,
      slug: 'home-repair',
      title: 'Home repair',
      titleUz: 'Uy ta’miri',
      titleRu: 'Ремонт дома',
      titleEn: 'Home repair',
      order: 0,
      isActive: true,
      services: [
        Category(id: 1, name: 'Plumbing', titleEn: 'Plumbing'),
        Category(id: 2, name: 'Electrical', titleEn: 'Electrical'),
        Category(id: 3, name: 'Windows', titleEn: 'Windows'),
      ],
    ),
    CategoryGroup(
      id: 2,
      slug: 'finishing',
      title: 'Finishing',
      titleUz: 'Ta’mirlash va bezash',
      titleRu: 'Отделка',
      titleEn: 'Finishing',
      order: 1,
      isActive: true,
      services: [
        Category(id: 4, name: 'Tiling', titleEn: 'Tiling'),
        Category(id: 5, name: 'Wallpaper', titleEn: 'Wallpaper'),
        Category(id: 6, name: 'Painting', titleEn: 'Painting'),
      ],
    ),
  ];
}

class _FakeChatService extends chat.ChatService {
  _FakeChatService() : super(kind: 'client');

  int conversationsCalls = 0;

  @override
  Future<List<chat.Conversation>> conversations() async {
    conversationsCalls++;
    return const [
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
}

void main() {
  testWidgets('pulling home down refreshes every home data source', (
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

    final orders = _FakeHomeOrderService();
    final notifications = _FakeNotificationService();
    final categories = _FakeCategoryService();
    final chats = _FakeChatService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          orderService: orders,
          notificationService: notifications,
          categoryService: categories,
          chatService: chats,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialAddressesCalls = orders.addressesCalls;
    final initialOrderCalls = orders.listCalls;
    final initialNotificationCalls = notifications.listCalls;
    final initialCategoryCalls = categories.getGroupsCalls;
    final initialChatCalls = chats.conversationsCalls;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(orders.addressesCalls, greaterThan(initialAddressesCalls));
    expect(orders.listCalls, greaterThan(initialOrderCalls));
    expect(notifications.listCalls, greaterThan(initialNotificationCalls));
    expect(categories.getGroupsCalls, greaterThan(initialCategoryCalls));
    expect(chats.conversationsCalls, greaterThan(initialChatCalls));
  });

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

    expect(find.textContaining('We’ll find a vetted master'), findsNothing);
    expect(find.text('Masters’ photos'), findsNothing);
    expect(find.text('Try faucet, TV mounting or cleaning'), findsOneWidget);
    final searchTopBeforeScroll = tester
        .getTopLeft(find.text('Try faucet, TV mounting or cleaning'))
        .dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final searchTopWhenPinned = tester
        .getTopLeft(find.text('Try faucet, TV mounting or cleaning'))
        .dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    final searchTopAfterMoreScroll = tester
        .getTopLeft(find.text('Try faucet, TV mounting or cleaning'))
        .dy;
    expect(searchTopWhenPinned, lessThan(searchTopBeforeScroll));
    expect((searchTopAfterMoreScroll - searchTopWhenPinned).abs(), lessThan(1));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
    await tester.pumpAndSettle();
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

  testWidgets('home keeps all category rows visible in a compact layout', (
    tester,
  ) async {
    final previousVisibilityInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval =
          previousVisibilityInterval;
    });
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
          categoryService: _FakeCatalogCategoryService(),
          chatService: _FakeChatService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose the service you need'), findsOneWidget);
    expect(find.text('Home repair'), findsOneWidget);
    expect(find.text('Finishing'), findsOneWidget);
    expect(
      find.byKey(const PageStorageKey('home-category-list-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const PageStorageKey('home-category-list-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-service-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-service-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-service-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-service-6')), findsOneWidget);
  });
}
