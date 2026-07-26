import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/core/network/auth_session.dart';

/// Payload of the `verification:update` event (see `api/Realtime.md`).
class MasterVerificationUpdate {
  const MasterVerificationUpdate({
    required this.verificationStatus,
    required this.accountStatus,
    this.rejectionReason,
    this.decidedAt,
  });

  /// `approved` | `rejected`.
  final String verificationStatus;

  /// `unverified` | `active` | `blocked`.
  final String accountStatus;
  final String? rejectionReason;
  final String? decidedAt;

  bool get isApproved => verificationStatus == 'approved';
  bool get isRejected => verificationStatus == 'rejected';

  factory MasterVerificationUpdate.fromJson(Map<String, dynamic> json) =>
      MasterVerificationUpdate(
        verificationStatus: json['verificationStatus'] as String? ?? '',
        accountStatus: json['accountStatus'] as String? ?? '',
        rejectionReason: json['rejectionReason'] as String?,
        decidedAt: json['decidedAt'] as String?,
      );
}

/// Live KYC updates for the master, over the `/master` Socket.IO namespace
/// (see `api/Realtime.md`).
///
/// WebSocket is a convenience, not the only channel — if it never connects the
/// master still sees the right state on re-login or via `GET /masters/me`.
/// On `token_expired` this auto-refreshes the access token (using the shared
/// [AuthSession]) and reconnects; on `forced_logout` it surfaces the reason so
/// the app can return the user to the login / blocked screen.
class MasterRealtimeService {
  MasterRealtimeService({AuthSession? session, String? socketBase})
    : socketBase = socketBase ?? ApiConfig.socketBaseUrl,
      _session = session ?? AuthSession.instance;

  final AuthSession _session;
  final String socketBase;

  io.Socket? _socket;

  /// Connects to `/master` with the current access token. Callbacks fire on the
  /// corresponding server events.
  void connect({
    required void Function(MasterVerificationUpdate update) onUpdate,
    void Function()? onConnected,
    void Function(String reason)? onForcedLogout,
    void Function()? onUnauthorized,
    void Function(int orderId)? onNewOrderNearby,
    void Function(int orderId)? onOrderCancelled,
    void Function(Map<String, dynamic> notification)? onNotification,
  }) {
    final token = _session.accessToken;
    if (token == null) return;

    final socket = io.io(
      '$socketBase/master',
      io.OptionBuilder()
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
        } else {
          onUnauthorized?.call();
        }
      } on Object {
        // Preserve the session on an offline/timeout error. A later reconnect
        // can retry without forcing the user through login.
      } finally {
        reconnecting = false;
      }
    }

    socket
      ..on('connected', (_) => onConnected?.call())
      ..on('verification:update', (data) {
        if (data is Map) {
          onUpdate(
            MasterVerificationUpdate.fromJson(Map<String, dynamic>.from(data)),
          );
        }
      })
      ..on('new_order_nearby', (data) {
        final id = (data is Map ? data['orderId'] : null) as num?;
        onNewOrderNearby?.call(id?.toInt() ?? 0);
      })
      ..on('order_cancelled', (data) {
        final id = (data is Map ? data['orderId'] : null) as num?;
        onOrderCancelled?.call(id?.toInt() ?? 0);
      })
      ..on('notification', (data) {
        if (data is Map) {
          onNotification?.call(Map<String, dynamic>.from(data));
        }
      })
      ..on('unauthorized', refreshAndReconnect)
      ..on('token_expired', refreshAndReconnect)
      ..on('forced_logout', (data) {
        final reason =
            (data is Map ? data['reason'] : null) as String? ??
            'account_blocked';
        onForcedLogout?.call(reason);
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
