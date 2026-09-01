import 'package:dio/dio.dart';

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_config.dart';

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _intN(dynamic v) => (v as num?)?.toInt();

/// One conversation in the chats list (order-scoped client↔master chat).
class Conversation {
  const Conversation({
    required this.id,
    required this.orderId,
    required this.orderTitle,
    this.writable = true,
    this.peerId,
    this.peerName,
    this.peerPhone,
    this.peerAvatarUrl,
    this.peerOnline = false,
    this.peerLastSeenAt,
    this.unreadCount = 0,
    this.lastMessageText,
    this.lastMessageType,
    this.lastMessageAt,
  });

  final int id;
  final int orderId;
  final String orderTitle;
  final bool writable;

  /// The peer's own account id (master id if [Conversation] was fetched by a
  /// client, client id if fetched by a master) — lets the UI open their full
  /// profile, not just show the name/avatar inline.
  final int? peerId;
  final String? peerName;
  final String? peerPhone;
  final String? peerAvatarUrl;
  final bool peerOnline;
  final DateTime? peerLastSeenAt;
  final int unreadCount;
  final String? lastMessageText;
  final String? lastMessageType;
  final DateTime? lastMessageAt;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final peer = j['peer'] as Map<String, dynamic>? ?? const {};
    final last = j['lastMessage'] as Map<String, dynamic>?;
    return Conversation(
      id: _int(j['id']),
      orderId: _int(j['orderId']),
      orderTitle: j['orderTitle'] as String? ?? '',
      writable: j['writable'] != false,
      peerId: _intN(peer['id']),
      peerName: peer['name'] as String?,
      peerPhone: peer['phone'] as String?,
      peerAvatarUrl: ApiConfig.resolveMediaUrl(peer['avatarUrl']),
      peerOnline: peer['online'] == true,
      peerLastSeenAt: DateTime.tryParse(peer['lastSeenAt']?.toString() ?? ''),
      unreadCount: _int(j['unreadCount']),
      lastMessageText: last?['text'] as String?,
      lastMessageType: last?['type'] as String?,
      lastMessageAt: DateTime.tryParse(last?['createdAt']?.toString() ?? ''),
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
    this.audioUrl,
    this.voiceDurationSec,
    this.fileMime,
    this.fileBytes,
    this.callStatus,
    this.callDurationSec,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.readAt,
    this.createdAt,
  });

  final int id;
  final String sender; // 'client' | 'master'
  final String type; // 'text' | 'image' | 'voice' | 'location' | 'call'
  final String? text;
  final String? imageUrl;
  final String? audioUrl;
  final int? voiceDurationSec;
  final String? fileMime;
  final int? fileBytes;
  final String? callStatus;
  final int? callDurationSec;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final DateTime? readAt;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final call = j['call'] as Map<String, dynamic>?;
    return ChatMessage(
      id: _int(j['id']),
      sender: j['sender'] as String? ?? '',
      type: j['type'] as String? ?? 'text',
      text: j['text'] as String?,
      imageUrl: ApiConfig.resolveMediaUrl(j['imageUrl']),
      audioUrl: ApiConfig.resolveMediaUrl(j['audioUrl']),
      voiceDurationSec: _intN(j['durationSec']),
      fileMime: j['fileMime'] as String?,
      fileBytes: _intN(j['fileBytes']),
      callStatus: call?['status'] as String?,
      callDurationSec: _intN(call?['durationSec']),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      locationLabel: j['locationLabel'] as String?,
      readAt: DateTime.tryParse(j['readAt']?.toString() ?? ''),
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

  /// One conversation — used by the chat screen for the peer's online status.
  Future<Conversation> conversation(int conversationId) async {
    final data = await _client.get('$_base/$conversationId');
    return Conversation.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> messages(
    int conversationId, {
    int? before,
    int limit = 30,
  }) async {
    final data = await _client.get(
      '$_base/$conversationId/messages',
      query: {'before': ?before, 'limit': limit},
    );
    return (data as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ChatMessage> sendText(int conversationId, String text) async {
    final data = await _client.post(
      '$_base/$conversationId/messages',
      body: {'text': text},
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatMessage> sendImage(
    int conversationId,
    String filePath, {
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.postMultipart(
      '$_base/$conversationId/messages/image',
      form,
      onSendProgress: onSendProgress,
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatMessage> sendVoice(
    int conversationId,
    String filePath,
    int durationSec,
  ) async {
    final form = FormData.fromMap({
      'durationSec': durationSec,
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.postMultipart(
      '$_base/$conversationId/messages/voice',
      form,
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatMessage> sendLocation(
    int conversationId, {
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final data = await _client.post(
      '$_base/$conversationId/messages/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      },
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<void> markRead(int conversationId) =>
      _client.post('$_base/$conversationId/read');
}
