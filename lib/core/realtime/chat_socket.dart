import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:fixleo/core/network/api_client.dart';
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
    this.socketBase = _defaultBase,
  }) : _session = session ?? AuthSession.instance;

  static const _defaultBase = 'http://localhost:9000'; // LOCAL DEV (prod: https://api.fixleo.com)

  final String kind; // 'client' | 'master'
  final int conversationId;
  final String socketBase;
  final AuthSession _session;

  io.Socket? _socket;

  /// Connects to `/{kind}` and calls [onMessage] for each new message on this
  /// conversation (including the peer's messages arriving in real time).
  void connect(void Function(ChatMessage message) onMessage) {
    final token = _session.accessToken;
    if (token == null) return;

    final socket = io.io(
      '$socketBase/$kind',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    socket
      ..on('chat_message', (data) {
        if (data is! Map) return;
        final convId = (data['conversationId'] as num?)?.toInt();
        if (convId != conversationId) return;
        final msg = data['message'];
        if (msg is Map) {
          onMessage(ChatMessage.fromJson(Map<String, dynamic>.from(msg)));
        }
      })
      ..on('token_expired', (_) async {
        // Refresh explicitly (sockets can't ride the REST 401 interceptor),
        // then reconnect with the fresh access token.
        await ApiClient.instance.refreshTokens();
        final fresh = _session.accessToken;
        if (fresh != null) {
          socket.auth = {'token': fresh};
          socket.connect();
        }
      });

    socket.connect();
    _socket = socket;
  }

  /// Disconnects and releases the socket. Call from `dispose()`.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
