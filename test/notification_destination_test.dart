import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/features/notifications/presentation/notification_destination.dart';
import 'package:fixleo/features/request/presentation/chat_screen.dart';
import 'package:fixleo/features/request/presentation/chats_list_screen.dart';
import 'package:fixleo/features/request/presentation/masters_responses_screen.dart';
import 'package:fixleo/features/request/presentation/order_status_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';
import 'package:fixleo/features/master/presentation/master_order_status_screen.dart';
import 'package:fixleo/features/master/presentation/master_request_detail_screen.dart';

void main() {
  test('chat routing accepts both FCM string and REST numeric IDs', () {
    for (final id in [41, '41']) {
      final screen =
          notificationDestination(
                kind: 'client',
                type: 'chat_message',
                data: {'conversationId': id},
              )
              as ChatScreen;
      expect(screen.conversationId, 41);
      expect(screen.kind, 'client');
    }
  });
  test('malformed chat IDs open the inbox instead of an invalid chat', () {
    for (final id in ['bad', '-1', '0', null]) {
      expect(
        notificationDestination(
          kind: 'master',
          type: 'chat_message',
          data: {'conversationId': id},
        ),
        isA<LiveChatsScreen>(),
      );
    }
  });
  test('client offers and reopened orders open actionable destinations', () {
    expect(
      notificationDestination(
        kind: 'client',
        type: 'offer_received',
        data: {'orderId': '12'},
      ),
      isA<MastersResponsesScreen>(),
    );
    expect(
      notificationDestination(
        kind: 'client',
        type: 'order_reopened',
        data: {'orderId': '12'},
      ),
      isA<OrderTrackingScreen>(),
    );
    expect(
      notificationDestination(
        kind: 'client',
        type: 'work_done',
        data: {'orderId': '12'},
      ),
      isA<OrderStatusScreen>(),
    );
  });
  test('master receives the proper detail/status screen', () {
    expect(
      notificationDestination(
        kind: 'master',
        type: 'new_order_nearby',
        data: {'orderId': 12},
      ),
      isA<MasterRequestDetailScreen>(),
    );
    expect(
      notificationDestination(
        kind: 'master',
        type: 'order_completed',
        data: {'orderId': 12},
      ),
      isA<MasterOrderStatusScreen>(),
    );
  });
  test(
    'invalid recipients and missing order IDs never create a detail route',
    () {
      expect(
        notificationDestination(
          kind: 'admin',
          type: 'chat_message',
          data: {'conversationId': 41},
        ),
        isNull,
      );
      expect(
        notificationDestination(
          kind: 'client',
          type: 'work_done',
          data: {'orderId': -1},
        ),
        isNull,
      );
      expect(
        notificationDestination(kind: 'client', type: 'work_done', data: {}),
        isNull,
      );
    },
  );
}
