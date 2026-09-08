import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/features/request/data/chat_service.dart';

/// Live incoming chat messages over the `/client` or `/master` Socket.IO
/// namespace. Fires [onMessage] for `chat_message` events on [conversationId].
///
/// This is a convenience layer on top of the REST fetch — if the socket never
/// connects, the thread still loads on open. Mirrors the auth/token-refresh
/// pattern of [MasterRealtimeService].
class ChatSocket {
  ChatSocket({
    required this.kind,
    required this.conversationId,
    AuthSession? session,
    String? socketBase,
  }) : socketBase = socketBase ?? ApiConfig.socketBaseUrl,
       _session = session ?? AuthSession.instance;

  final String kind; // 'client' | 'master'
  final int conversationId;
  final String socketBase;
  final AuthSession _session;

  io.Socket? _socket;

  /// Connects to `/{kind}` and forwards new messages plus peer read receipts for
  /// this conversation. Older servers may omit `upToMessageId`; in that case a
  /// receipt means every currently visible outgoing message was read.
  void connect(
    void Function(ChatMessage message) onMessage, {
    void Function(int? upToMessageId)? onRead,
    void Function()? onConnected,
  }) {
    disconnect();
    final token = _session.accessToken;
    if (token == null) return;

    final socket = io.io(
      '$socketBase/$kind',
      io.OptionBuilder()
          .enableForceNew()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    var reconnecting = false;
    Future<void> refreshAndReconnect(_) async {
      if (reconnecting) return;
      reconnecting = true;
      try {
        final refreshed = await ApiClient.instance.refreshTokens();
        final fresh = _session.accessToken;
        if (refreshed && fresh != null) {
          socket.disconnect();
          socket.auth = {'token': fresh};
          socket.connect();
        }
      } on Object {
        // A temporary network failure keeps the persisted session. The REST
        // layer or a later socket reconnect will retry the same refresh token.
      } finally {
        reconnecting = false;
      }
    }

    socket
      ..onConnect((_) => onConnected?.call())
      ..on('chat_message', (data) {
        if (data is! Map) return;
        final convId = (data['conversationId'] as num?)?.toInt();
        if (convId != conversationId) return;
        final msg = data['message'];
        if (msg is Map) {
          onMessage(ChatMessage.fromJson(Map<String, dynamic>.from(msg)));
        }
      })
      ..on('chat_read', (data) {
        if (data is! Map) return;
        final convId = (data['conversationId'] as num?)?.toInt();
        if (convId != conversationId) return;
        onRead?.call((data['upToMessageId'] as num?)?.toInt());
      })
      ..on('token_expired', refreshAndReconnect)
      ..on('unauthorized', refreshAndReconnect);

    socket.connect();
    _socket = socket;
  }

  /// Disconnects and releases the socket. Call from `dispose()`.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
