import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/auth_session.dart';

/// Lifecycle of a voice call as seen by the UI.
enum CallState { idle, calling, incoming, active, ended }

/// A live client↔master voice call over WebRTC, signalled through the backend
/// `/calls` Socket.IO namespace (offer / answer / ice / end — see the server
/// CallGateway). Audio is peer-to-peer; this service owns the peer connection,
/// the microphone track and the signalling. A singleton so an incoming call can
/// ring from anywhere the service was connected.
///
/// NOTE: WebRTC audio needs a real microphone — it cannot be exercised on the
/// iOS Simulator (no mic hardware). On device it requires the microphone
/// permission (Info.plist `NSMicrophoneUsageDescription`).
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  static const _socketBase = 'http://localhost:9000'; // LOCAL DEV (prod: https://api.fixleo.com)
  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  final AuthSession _session = AuthSession.instance;

  io.Socket? _socket;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  int? _callId;
  Map<String, dynamic>? _pendingOffer; // remote SDP for an unaccepted incoming call
  final List<RTCIceCandidate> _pendingRemoteIce = [];

  /// Current call state — the UI listens to this.
  final ValueNotifier<CallState> state = ValueNotifier(CallState.idle);

  /// Who is on the other end (for the incoming/outgoing UI). Set by the caller.
  final ValueNotifier<String?> peerName = ValueNotifier(null);

  /// Fired when a call:incoming arrives and there's no active call — the app can
  /// present the incoming-call UI. Registered once at connect time.
  void Function()? _onIncoming;

  bool get isBusy => state.value != CallState.idle && state.value != CallState.ended;

  /// Connect the signalling socket for [kind] ('client' | 'master'). The token
  /// identifies the user to the `/calls` namespace. Safe to call repeatedly.
  void connect(String kind, {void Function()? onIncoming}) {
    _onIncoming = onIncoming;
    if (_socket != null) return;
    final token = _session.accessToken;
    if (token == null) return;

    final socket = io.io(
      '$_socketBase/calls',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    socket
      ..on('call:incoming', _handleIncoming)
      ..on('call:answered', _handleAnswered)
      ..on('call:ice', _handleRemoteIce)
      ..on('call:ended', (_) => _teardown(CallState.ended))
      ..on('call:rejected', (_) => _teardown(CallState.ended))
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

  // ------------------------------------------------------------------ outgoing

  /// Place a call to the peer on [conversationId].
  Future<void> startCall(int conversationId, {String? displayName}) async {
    if (_socket == null || isBusy) return;
    peerName.value = displayName;
    state.value = CallState.calling;
    await _createPeer();
    final offer = await _pc!.createOffer({'offerToReceiveAudio': true});
    await _pc!.setLocalDescription(offer);
    _socket!.emitWithAck(
      'call:offer',
      {'conversationId': conversationId, 'sdp': offer.toMap()},
      ack: (dynamic res) {
        if (res is Map && res['callId'] != null) {
          _callId = (res['callId'] as num).toInt();
        } else {
          _teardown(CallState.ended); // rejected by server (busy / not a member)
        }
      },
    );
  }

  Future<void> _handleAnswered(dynamic data) async {
    if (data is! Map || _pc == null) return;
    final sdp = data['sdp'];
    if (sdp is Map) {
      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdp['sdp'] as String?, sdp['type'] as String?),
      );
      await _drainPendingIce();
      state.value = CallState.active;
    }
  }

  // ------------------------------------------------------------------ incoming

  void _handleIncoming(dynamic data) {
    if (data is! Map || isBusy) return;
    _callId = (data['callId'] as num?)?.toInt();
    final sdp = data['sdp'];
    _pendingOffer = sdp is Map ? Map<String, dynamic>.from(sdp) : null;
    peerName.value = data['from'] as String?;
    state.value = CallState.incoming;
    _onIncoming?.call();
  }

  /// Accept the ringing incoming call.
  Future<void> answer() async {
    if (_socket == null || _callId == null || _pendingOffer == null) return;
    await _createPeer();
    await _pc!.setRemoteDescription(
      RTCSessionDescription(_pendingOffer!['sdp'] as String?, _pendingOffer!['type'] as String?),
    );
    await _drainPendingIce();
    final answer = await _pc!.createAnswer({'offerToReceiveAudio': true});
    await _pc!.setLocalDescription(answer);
    _socket!.emit('call:answer', {'callId': _callId, 'sdp': answer.toMap()});
    _pendingOffer = null;
    state.value = CallState.active;
  }

  /// Decline the ringing incoming call.
  void reject() {
    if (_socket != null && _callId != null) {
      _socket!.emit('call:reject', {'callId': _callId});
    }
    _teardown(CallState.ended);
  }

  // ------------------------------------------------------------------ common

  /// Hang up an active or outgoing call.
  void hangup() {
    if (_socket != null && _callId != null) {
      _socket!.emit('call:end', {'callId': _callId});
    }
    _teardown(CallState.ended);
  }

  bool _muted = false;
  bool get isMuted => _muted;

  /// Toggle the local microphone.
  void toggleMute() {
    _muted = !_muted;
    for (final track in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !_muted;
    }
  }

  Future<void> _createPeer() async {
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    final pc = await createPeerConnection(_iceServers);
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }
    pc.onIceCandidate = (candidate) {
      if (_socket != null && _callId != null) {
        _socket!.emit('call:ice', {'callId': _callId, 'candidate': candidate.toMap()});
      }
    };
    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _teardown(CallState.ended);
      }
    };
    _pc = pc;
  }

  Future<void> _handleRemoteIce(dynamic data) async {
    if (data is! Map) return;
    final c = data['candidate'];
    if (c is! Map) return;
    final candidate = RTCIceCandidate(
      c['candidate'] as String?,
      c['sdpMid'] as String?,
      (c['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (_pc == null) {
      _pendingRemoteIce.add(candidate); // arrived before the peer was ready
    } else {
      await _pc!.addCandidate(candidate);
    }
  }

  Future<void> _drainPendingIce() async {
    for (final c in _pendingRemoteIce) {
      await _pc?.addCandidate(c);
    }
    _pendingRemoteIce.clear();
  }

  Future<void> _teardown(CallState finalState) async {
    state.value = finalState;
    for (final track in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _pc?.close();
    _localStream = null;
    _pc = null;
    _callId = null;
    _pendingOffer = null;
    _pendingRemoteIce.clear();
    _muted = false;
    // Reset to idle shortly so the UI can show the "ended" state briefly.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (state.value == CallState.ended) state.value = CallState.idle;
    });
  }

  /// Fully disconnect the signalling socket (e.g. on logout).
  void disconnect() {
    _teardown(CallState.idle);
    _socket?.dispose();
    _socket = null;
  }
}
