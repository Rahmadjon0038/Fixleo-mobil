import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/request/data/feedback_service.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/order_done_screen.dart';
import 'package:fixleo/features/request/presentation/order_status_screen.dart';
import 'package:fixleo/features/request/presentation/rate_master_screen.dart';

const _realOrder = OrderDetail(
  id: 10,
  title: 'CODEX QA Plumbing',
  description: 'Leaking pipe',
  status: 'work_done',
  addressText: 'Tashkent',
  timing: 'asap',
  agreedPrice: 100000,
  master: OrderMasterInfo(numericId: 3, name: 'Hojiakbar Master'),
  capabilities: OrderCapabilities(canConfirm: true, canReview: true),
);

class _FakeOrderService extends OrderService {
  _FakeOrderService({this.order = _realOrder});

  final OrderDetail order;
  int confirms = 0;

  @override
  Future<OrderDetail> detail(int id) async => order;

  @override
  Future<OrderDetail> confirmCompletion(int id) async {
    confirms++;
    return order;
  }
}

class _FakeFeedbackService extends FeedbackService {
  int reviews = 0;

  @override
  Future<void> review(
    int orderId, {
    required int rating,
    List<String> tags = const [],
    String? text,
  }) async {
    reviews++;
  }
}

void main() {
  setUp(() => LocaleController.language.value = AppLanguage.en);
  tearDown(() => LocaleController.language.value = AppLanguage.ru);

  testWidgets('completion confirmation renders only real order data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OrderDoneScreen(orderId: 10, orderService: _FakeOrderService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CODEX QA Plumbing'), findsOneWidget);
    expect(find.text('Urgent — now'), findsOneWidget);
    expect(find.text('100 000 sum'), findsOneWidget);
    expect(find.textContaining('Faucet'), findsNothing);
  });

  testWidgets('on-the-way timeline does not mark arrived as current', (
    tester,
  ) async {
    final service = _FakeOrderService(
      order: const OrderDetail(
        id: 10,
        title: 'Live status',
        description: 'Status test',
        status: 'on_the_way',
        addressText: 'Tashkent',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: OrderStatusScreen(orderId: 10, orderService: service)),
    );
    await tester.pumpAndSettle();

    final onWay = find.ancestor(
      of: find.text('Master on the way'),
      matching: find.byType(Row),
    );
    final arrived = find.ancestor(
      of: find.text('Master arrived'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: onWay.first, matching: find.text('Now')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: arrived.first, matching: find.text('Pending')),
      findsOneWidget,
    );
  });

  testWidgets('rating header uses the assigned master and order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RateMasterScreen(
          orderId: 10,
          orderService: _FakeOrderService(),
          feedbackService: _FakeFeedbackService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hojiakbar Master'), findsOneWidget);
    expect(find.text('CODEX QA Plumbing · Urgent — now'), findsOneWidget);
    expect(find.textContaining('Aleksey'), findsNothing);
    expect(find.textContaining('Faucet'), findsNothing);
  });
}
