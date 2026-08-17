import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/order_declined_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';
import 'package:fixleo/features/request/presentation/waiting_responses_screen.dart';

class _WaitingOrderService extends OrderService {
  @override
  Future<List<OfferView>> offers(int id, {String sort = 'rating'}) async =>
      const [];
}

class _ReopenedOrderService extends OrderService {
  var detailCalls = 0;

  @override
  Future<OrderDetail> detail(int id) async {
    detailCalls++;
    return OrderDetail(
      id: id,
      title: 'Sink repair',
      description: 'Kitchen sink',
      status: detailCalls == 1 ? 'assigned' : 'searching',
      addressText: 'Tashkent',
    );
  }
}

void main() {
  testWidgets('back from the submitted request waiting screen opens Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WaitingResponsesScreen(
          orderId: 77,
          service: _WaitingOrderService(),
          homeBuilder: (_) =>
              const Scaffold(key: ValueKey('client-home-destination')),
        ),
      ),
    );
    await tester.pump();

    final back = find.ancestor(
      of: find.byIcon(Icons.arrow_back),
      matching: find.byType(GestureDetector),
    );
    tester.widget<GestureDetector>(back.first).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WaitingResponsesScreen), findsNothing);
    expect(
      find.byKey(const ValueKey('client-home-destination')),
      findsOneWidget,
    );
  });

  testWidgets(
    'master cancellation reopening the order shows the declined Figma flow',
    (tester) async {
      final service = _ReopenedOrderService();
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(orderId: 91, orderService: service),
        ),
      );
      await tester.pump();
      expect(find.byType(OrderTrackingScreen), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDeclinedScreen), findsOneWidget);
      expect(find.text('Перейти к откликам'), findsOneWidget);
    },
  );

  testWidgets('"Go to responses" replaces the declined screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDeclinedScreen(
          orderId: 91,
          responsesBuilder: (_) =>
              const Scaffold(key: ValueKey('responses-destination')),
        ),
      ),
    );

    await tester.tap(find.text('Перейти к откликам'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDeclinedScreen), findsNothing);
    expect(find.byKey(const ValueKey('responses-destination')), findsOneWidget);
  });
}
