import 'package:flutter/widgets.dart';
import 'package:fixleo/features/master/presentation/master_order_status_screen.dart';
import 'package:fixleo/features/master/presentation/master_request_detail_screen.dart';
import 'package:fixleo/features/request/presentation/chat_screen.dart';
import 'package:fixleo/features/request/presentation/chats_list_screen.dart';
import 'package:fixleo/features/request/presentation/masters_responses_screen.dart';
import 'package:fixleo/features/request/presentation/order_status_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';

/// Shared by FCM taps and the in-app inbox. FCM encodes IDs as strings whereas
/// the REST inbox uses numbers; both must open the same actionable screen.
Widget? notificationDestination({
  required String kind,
  required String type,
  required Map<String, dynamic> data,
}) {
  if (kind != 'client' && kind != 'master') return null;
  int? id(String key) {
    final value = int.tryParse(data[key]?.toString() ?? '');
    return value != null && value > 0 ? value : null;
  }

  if (type == 'chat_message') {
    final conversationId = id('conversationId');
    return conversationId != null
        ? ChatScreen(conversationId: conversationId, kind: kind)
        : LiveChatsScreen(kind: kind);
  }
  final orderId = id('orderId');
  if (orderId == null) return null;
  if (kind == 'master') {
    return type == 'new_order_nearby'
        ? MasterRequestDetailScreen(orderId: orderId)
        : MasterOrderStatusScreen(orderId: orderId);
  }
  if (type == 'offer_received') {
    return MastersResponsesScreen(orderId: orderId);
  }
  if (type == 'order_reopened') {
    return OrderTrackingScreen(orderId: orderId);
  }
  return OrderStatusScreen(orderId: orderId);
}
