import 'package:dio/dio.dart';

import 'package:fixleo/core/network/api_client.dart';

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _intN(dynamic v) => (v as num?)?.toInt();

/// One conversation in the chats list (order-scoped client↔master chat).
class Conversation {
  const Conversation({
    required this.id,
    required this.orderId,
    required this.orderTitle,
    this.writable = true,
    this.peerName,
    this.peerPhone,
    this.peerOnline = false,
    this.unreadCount = 0,
    this.lastMessageText,
    this.lastMessageType,
  });

  final int id;
  final int orderId;
  final String orderTitle;
  final bool writable;
  final String? peerName;
  final String? peerPhone;
  final bool peerOnline;
  final int unreadCount;
  final String? lastMessageText;
  final String? lastMessageType;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final peer = j['peer'] as Map<String, dynamic>? ?? const {};
    final last = j['lastMessage'] as Map<String, dynamic>?;
    return Conversation(
      id: _int(j['id']),
      orderId: _int(j['orderId']),
      orderTitle: j['orderTitle'] as String? ?? '',
      writable: j['writable'] != false,
      peerName: peer['name'] as String?,
      peerPhone: peer['phone'] as String?,
      peerOnline: peer['online'] == true,
      unreadCount: _int(j['unreadCount']),
      lastMessageText: last?['text'] as String?,
      lastMessageType: last?['type'] as String?,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.type,
    this.text,
    this.imageUrl,
    this.callStatus,
    this.callDurationSec,
    this.createdAt,
  });

  final int id;
  final String sender; // 'client' | 'master'
  final String type; // 'text' | 'image' | 'call'
  final String? text;
  final String? imageUrl;
  final String? callStatus;
  final int? callDurationSec;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final call = j['call'] as Map<String, dynamic>?;
    return ChatMessage(
      id: _int(j['id']),
      sender: j['sender'] as String? ?? '',
      type: j['type'] as String? ?? 'text',
      text: j['text'] as String?,
      imageUrl: j['imageUrl'] as String?,
      callStatus: call?['status'] as String?,
      callDurationSec: _intN(call?['durationSec']),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
    );
  }
}

/// Order chat (see docs/v3/Chat.md). The same endpoints exist under
/// `/clients/me/…` and `/masters/me/…`; [kind] picks the prefix.
class ChatService {
  ChatService({required this.kind, ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final String kind; // 'client' | 'master'
  final ApiClient _client;

  String get _base => '/${kind}s/me/conversations';

  Future<List<Conversation>> conversations() async {
    final data = await _client.get(_base);
    return (data as List<dynamic>)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<ChatMessage>> messages(int conversationId, {int? before, int limit = 30}) async {
    final data = await _client.get('$_base/$conversationId/messages', query: {
      if (before != null) 'before': before,
      'limit': limit,
    });
    return (data as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ChatMessage> sendText(int conversationId, String text) async {
    final data = await _client.post('$_base/$conversationId/messages', body: {'text': text});
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatMessage> sendImage(int conversationId, String filePath) async {
    final form = FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
    final data = await _client.postMultipart('$_base/$conversationId/messages/image', form);
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<void> markRead(int conversationId) =>
      _client.post('$_base/$conversationId/read');
}
