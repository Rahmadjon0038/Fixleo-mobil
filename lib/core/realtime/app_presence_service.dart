import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/core/network/auth_session.dart';

/// A live presence change for one of the current user's conversations.
class PresenceUpdate {
  const PresenceUpdate({
    required this.conversationId,
    required this.online,
    required this.lastSeenAt,
  });

  final int conversationId;
  final bool online;
  final DateTime lastSeenAt;

  factory PresenceUpdate.fromJson(Map<String, dynamic> json) {
    return PresenceUpdate(
      conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
      online: json['online'] == true,
      lastSeenAt:
          DateTime.tryParse(json['lastSeenAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Authoritative app-level presence for client and master accounts.
///
/// Only this socket sends `presence: true`; chat/order/call sockets may use the
/// same namespace but do not affect online state. The app root connects it in
/// foreground and disposes it in background, so "online" means the user is
/// anywhere inside Fixleo — not merely inside a chat screen.
class AppPresenceService {
  AppPresenceService._();

  static final AppPresenceService instance = AppPresenceService._();

  final StreamController<PresenceUpdate> _updates =
      StreamController<PresenceUpdate>.broadcast();
  final StreamController<int> _conversationUpdates =
      StreamController<int>.broadcast();

  Stream<PresenceUpdate> get updates => _updates.stream;

  /// Conversation ids whose message/read state changed while the app is open.
  /// Chat lists use this lightweight signal to refresh unread badges and
  /// previews without maintaining a second app-wide Socket.IO connection.
  Stream<int> get conversationUpdates => _conversationUpdates.stream;

  io.Socket? _socket;
  AuthRole? _connectedRole;
  bool _foreground = false;
  bool _refreshing = false;

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      disconnect();
      return;
    }
    connectForCurrentSession();
  }

  /// Connects the global tracker for the currently authenticated app account.
  /// Admin sessions are intentionally excluded from client/master presence.
  void connectForCurrentSession() {
    if (!_foreground) return;
    final session = AuthSession.instance;
    final role = session.role;
    final token = session.accessToken;
    if (token == null ||
        token.isEmpty ||
        (role != AuthRole.client && role != AuthRole.master)) {
      disconnect();
      return;
    }

    if (_socket != null && _connectedRole == role) {
      if (_socket!.disconnected) _socket!.connect();
      return;
    }

    disconnect();
    _connectedRole = role;
    final socket = io.io(
      '${ApiConfig.socketBaseUrl}/${role!.name}',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token, 'presence': true})
          .enableReconnection()
          .setReconnectionAttempts(1000000)
          .setReconnectionDelay(1000)
          .disableAutoConnect()
          .build(),
    );

    Future<void> refreshAndReconnect(_) async {
      if (_refreshing || !_foreground) return;
      _refreshing = true;
      try {
        final refreshed = await ApiClient.instance.refreshTokens();
        final fresh = AuthSession.instance.accessToken;
        if (refreshed &&
            fresh != null &&
            _foreground &&
            identical(_socket, socket)) {
          socket.disconnect();
          socket.auth = {'token': fresh, 'presence': true};
          socket.connect();
        }
      } on Object {
        // A temporary network failure is not a logout. Socket.IO keeps retrying
        // and the shared refresh layer will retry when connectivity returns.
      } finally {
        _refreshing = false;
      }
    }

    socket
      ..on('presence:update', (data) {
        if (data is! Map) return;
        final update = PresenceUpdate.fromJson(Map<String, dynamic>.from(data));
        if (update.conversationId > 0) _updates.add(update);
      })
      ..on('chat_message', _notifyConversationChanged)
      ..on('chat_read', _notifyConversationChanged)
      ..on('token_expired', refreshAndReconnect)
      ..on('unauthorized', refreshAndReconnect)
      ..connect();
    _socket = socket;
  }

  /// Stops reconnection too; a paused/background app must stay offline.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectedRole = null;
    _refreshing = false;
  }

  void _notifyConversationChanged(dynamic data) {
    if (data is! Map) return;
    final conversationId = (data['conversationId'] as num?)?.toInt() ?? 0;
    if (conversationId > 0) {
      _conversationUpdates.add(conversationId);
    }
  }
}
