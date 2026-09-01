import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:record/record.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/realtime/call_ice_config.dart';
import 'package:fixleo/core/realtime/call_recording_retry_queue.dart';

/// Lifecycle of a voice call as seen by the UI.
enum CallState { idle, calling, incoming, connecting, active, busy, ended }

class IncomingCallSignal {
  const IncomingCallSignal({
    required this.callId,
    required this.callUuid,
    required this.conversationId,
    required this.from,
    required this.displayName,
  });

  final int callId;
  final String callUuid;
  final int conversationId;
  final String from;
  final String displayName;
}

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

  static const _disconnectGrace = Duration(seconds: 10);
  static const _iceConfigTimeout = Duration(seconds: 5);
  static const _ringTimeout = Duration(seconds: 60);

  final AuthSession _session = AuthSession.instance;
  final CallRecordingRetryQueue _recordingQueue =
      CallRecordingRetryQueue.instance;

  io.Socket? _socket;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  DateTime? _activeSince;
  String? _kind;
  int? _connectedOwnerId;

  int? _callId;
  String? _callUuid;
  Map<String, dynamic>?
  _pendingOffer; // remote SDP for an unaccepted incoming call
  final List<RTCIceCandidate> _pendingLocalIce = [];
  final List<RTCIceCandidate> _pendingRemoteIce = [];
  MediaRecorder? _androidRecorder;
  AudioRecorder? _iosRecorder;
  String? _recordingPath;
  int? _recordingOwnerId;
  Future<void>? _recordingStartTask;
  Future<void>? _teardownTask;
  Future<void>? _remoteIceDrainTask;
  Future<void>? _recordingRetryTask;
  bool _recordingRetryRequested = false;
  Timer? _recordingRetryTimer;
  DateTime? _recordingRetryAt;
  Timer? _disconnectGraceTimer;
  Timer? _ringTimeoutTimer;

  /// Current call state — the UI listens to this.
  final ValueNotifier<CallState> state = ValueNotifier(CallState.idle);

  /// Localized server explanation for a temporary terminal state such as busy.
  final ValueNotifier<String?> statusMessage = ValueNotifier(null);

  /// Who is on the other end (for the incoming/outgoing UI). Set by the caller.
  final ValueNotifier<String?> peerName = ValueNotifier(null);

  /// The instant the peer-to-peer audio connection actually became active.
  /// Call UI uses this as the single source of truth for its duration timer.
  DateTime? get activeSince => _activeSince;

  /// Fired when a call:incoming arrives and there's no active call — the app can
  /// present the incoming-call UI. Registered once at connect time.
  void Function(IncomingCallSignal signal)? _onIncoming;

  String? get currentCallUuid => _callUuid;

  bool get isBusy =>
      _teardownTask != null ||
      (state.value != CallState.idle && state.value != CallState.ended);

  @visibleForTesting
  bool get hasSignallingSocket => _socket != null;

  @visibleForTesting
  String? get connectedKind => _kind;

  @visibleForTesting
  int? get connectedOwnerId => _connectedOwnerId;

  /// Connect the signalling socket for [kind] ('client' | 'master'). The token
  /// identifies the user to the `/calls` namespace. Safe to call repeatedly.
  void connect(
    String kind, {
    void Function(IncomingCallSignal signal)? onIncoming,
  }) {
    if (onIncoming != null) _onIncoming = onIncoming;
    final token = _session.accessToken;
    final ownerId = _session.subjectId;
    if (token == null || ownerId == null) return;

    if (_socket != null) {
      if (_kind == kind && _connectedOwnerId == ownerId) {
        unawaited(retryPendingRecordings());
        return;
      }
      // A different account/role replaced the session without reusing the old
      // signalling identity. Never leave the previous account's socket alive.
      disconnect();
    }
    _kind = kind;
    _connectedOwnerId = ownerId;

    final socket = io.io(
      '${ApiConfig.socketBaseUrl}/calls',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({
            'token': token,
            'lang': LocaleController.language.value.name,
          })
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
        if (refreshed &&
            fresh != null &&
            identical(_socket, socket) &&
            _kind == kind &&
            _connectedOwnerId == ownerId) {
          socket.disconnect();
          socket.auth = {
            'token': fresh,
            'lang': LocaleController.language.value.name,
          };
          socket.connect();
        }
      } on Object {
        // Offline is recoverable. ApiClient deliberately keeps the refresh
        // token so a later request/reconnect can try again.
      } finally {
        reconnecting = false;
      }
    }

    socket
      ..on('call:incoming', _handleIncoming)
      ..on('call:answered', _handleAnswered)
      ..on('call:ice', _handleRemoteIce)
      ..on('call:ended', (_) => _teardown(CallState.ended))
      ..on('call:rejected', (_) => _teardown(CallState.ended))
      ..on('token_expired', refreshAndReconnect)
      ..on('unauthorized', refreshAndReconnect)
      ..onConnect((_) => unawaited(retryPendingRecordings()));

    socket.connect();
    _socket = socket;
    unawaited(retryPendingRecordings());
  }

  /// Follows the app's one active login. Logout/admin sessions close the calls
  /// socket; client/master sessions connect with the matching identity.
  void syncForCurrentSession({
    void Function(IncomingCallSignal signal)? onIncoming,
  }) {
    final role = _session.role;
    if (!_session.isLoggedIn ||
        (role != AuthRole.client && role != AuthRole.master)) {
      disconnect();
      return;
    }
    connect(role!.name, onIncoming: onIncoming);
  }

  // ------------------------------------------------------------------ outgoing

  /// Place a call to the peer on [conversationId].
  Future<void> startCall(int conversationId, {String? displayName}) async {
    if (_socket == null || isBusy) return;
    peerName.value = displayName;
    statusMessage.value = null;
    state.value = CallState.calling;
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = Timer(_ringTimeout, () {
      _ringTimeoutTimer = null;
      if (state.value == CallState.calling) hangup();
    });
    try {
      await _createPeer();
      final offer = await _pc!.createOffer({'offerToReceiveAudio': true});
      await _pc!.setLocalDescription(offer);
      _socket!.emitWithAck(
        'call:offer',
        {'conversationId': conversationId, 'sdp': offer.toMap()},
        ack: (dynamic res) {
          if (res is Map && res['callId'] != null) {
            _callId = (res['callId'] as num).toInt();
            _drainPendingLocalIce();
          } else {
            final lineBusy = res is Map && res['code'] == 'line_busy';
            statusMessage.value = res is Map ? res['error'] as String? : null;
            unawaited(_teardown(lineBusy ? CallState.busy : CallState.ended));
          }
        },
      );
    } on Object {
      await _teardown(CallState.ended);
    }
  }

  Future<void> _handleAnswered(dynamic data) async {
    if (data is! Map || _pc == null) return;
    final sdp = data['sdp'];
    if (sdp is Map) {
      _ringTimeoutTimer?.cancel();
      _ringTimeoutTimer = null;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdp['sdp'] as String?, sdp['type'] as String?),
      );
      await _drainPendingIce();
      state.value = CallState.connecting;
      // Both users have accepted at this point. Attach the recorder before ICE
      // finishes so a fast connection/hang-up cannot race recorder startup.
      _ensureRecordingStarted();
    }
  }

  // ------------------------------------------------------------------ incoming

  void _handleIncoming(dynamic data) {
    if (data is! Map) return;
    final callId = (data['callId'] as num?)?.toInt();
    final callUuid = data['callUuid']?.toString();
    final conversationId = (data['conversationId'] as num?)?.toInt();
    if (callId == null || callUuid == null || conversationId == null) return;
    if (isBusy && _callId != callId) return;
    _callId = callId;
    _callUuid = callUuid;
    final sdp = data['sdp'];
    _pendingOffer = sdp is Map ? Map<String, dynamic>.from(sdp) : null;
    peerName.value = data['displayName'] as String? ?? data['from'] as String?;
    state.value = CallState.incoming;
    _onIncoming?.call(
      IncomingCallSignal(
        callId: callId,
        callUuid: callUuid,
        conversationId: conversationId,
        from: data['from']?.toString() ?? 'client',
        displayName: peerName.value ?? 'Fixleo',
      ),
    );
  }

  /// Restore an offer after FCM/PushKit woke a suspended or terminated app,
  /// then answer through the normal WebRTC + Socket.IO path.
  Future<void> answerFromNative({
    required int callId,
    required String callUuid,
    required String callerName,
    required VoidCallback onShowUi,
  }) async {
    if (isBusy && _callId != callId) return;
    _callId = callId;
    _callUuid = callUuid;
    peerName.value = callerName;
    state.value = CallState.incoming;
    onShowUi();
    syncForCurrentSession(onIncoming: _onIncoming);

    try {
      if (_pendingOffer == null) {
        final kind = _kind;
        if (kind != 'client' && kind != 'master') {
          throw StateError('Call session is unavailable');
        }
        final raw = await ApiClient.instance.get(
          '/${kind}s/me/calls/$callId/invite',
        );
        if (raw is! Map) throw const FormatException('Invalid call invite');
        final invite = Map<String, dynamic>.from(raw);
        if (invite['callUuid']?.toString().toLowerCase() !=
            callUuid.toLowerCase()) {
          throw const FormatException('Call UUID mismatch');
        }
        final sdp = invite['sdp'];
        if (sdp is! Map) throw const FormatException('Missing call offer');
        _pendingOffer = Map<String, dynamic>.from(sdp);
        final candidates = invite['iceCandidates'];
        if (candidates is List) {
          for (final candidate in candidates) {
            if (candidate is Map) _queueRemoteCandidate(candidate);
          }
        }
      }
      await answer();
    } on Object catch (error) {
      debugPrint('Incoming call recovery failed: $error');
      _failCall();
    }
  }

  /// Accept the ringing incoming call.
  Future<void> answer() async {
    if (_socket == null || _callId == null || _pendingOffer == null) return;
    try {
      await _createPeer();
      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          _pendingOffer!['sdp'] as String?,
          _pendingOffer!['type'] as String?,
        ),
      );
      await _drainPendingIce();
      final answer = await _pc!.createAnswer({'offerToReceiveAudio': true});
      await _pc!.setLocalDescription(answer);
      _socket!.emit('call:answer', {'callId': _callId, 'sdp': answer.toMap()});
      _pendingOffer = null;
      state.value = CallState.connecting;
      _ensureRecordingStarted();
    } on Object {
      _failCall();
    }
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
      final activeSince = _activeSince;
      _socket!.emit('call:end', {
        'callId': _callId,
        if (activeSince != null)
          'durationSec': DateTime.now().difference(activeSince).inSeconds,
      });
    }
    _teardown(CallState.ended);
  }

  bool _muted = false;
  bool get isMuted => _muted;
  bool _speakerOn = false;
  bool get isSpeakerOn => _speakerOn;

  /// Toggle the local microphone.
  void toggleMute() {
    _muted = !_muted;
    for (final track
        in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !_muted;
    }
    final recorder = _iosRecorder;
    if (recorder != null) {
      unawaited(_muted ? recorder.pause() : recorder.resume());
    }
  }

  /// Route call audio between the phone earpiece and loudspeaker.
  Future<void> toggleSpeaker() async {
    final next = !_speakerOn;
    await Helper.setSpeakerphoneOn(next);
    _speakerOn = next;
  }

  Future<void> _createPeer() async {
    final iceConfiguration = await _loadIceConfiguration();
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    final pc = await createPeerConnection(iceConfiguration);
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }
    pc.onIceCandidate = (candidate) {
      if (_socket == null) return;
      if (_callId == null) {
        _pendingLocalIce.add(candidate);
      } else {
        _emitIce(candidate);
      }
    };
    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markMediaConnected();
      } else if (s ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _scheduleDisconnectFailure(pc);
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _cancelDisconnectGrace();
        _failCall();
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _cancelDisconnectGrace();
      }
    };
    // Some Android WebRTC builds establish a usable ICE transport but do not
    // subsequently emit the aggregate PeerConnectionState `connected` event.
    // ICE carries the media, so use its connected/completed states as the
    // authoritative fallback for the call timer and recording lifecycle.
    pc.onIceConnectionState = (s) {
      if (s == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          s == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _markMediaConnected();
      } else if (s == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _scheduleDisconnectFailure(pc);
      } else if (s == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _cancelDisconnectGrace();
        _failCall();
      } else if (s == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _cancelDisconnectGrace();
      }
    };
    _pc = pc;
  }

  void _markMediaConnected() {
    _cancelDisconnectGrace();
    _activeSince ??= DateTime.now();
    state.value = CallState.active;
    final callUuid = _callUuid;
    if (callUuid != null) {
      unawaited(FlutterCallkitIncoming.setCallConnected(callUuid));
    }
    _ensureRecordingStarted();
  }

  void _scheduleDisconnectFailure(RTCPeerConnection pc) {
    _disconnectGraceTimer ??= Timer(_disconnectGrace, () {
      _disconnectGraceTimer = null;
      if (identical(_pc, pc)) _failCall();
    });
  }

  Future<Map<String, dynamic>> _loadIceConfiguration() async {
    final kind = _kind;
    if (kind != 'client' && kind != 'master') {
      return CallIceConfiguration.fallback.toPeerConnectionConfiguration();
    }
    try {
      final data = await ApiClient.instance
          .get('/${kind}s/me/calls/ice-config')
          .timeout(_iceConfigTimeout);
      return CallIceConfiguration.fromApi(data).toPeerConnectionConfiguration();
    } on Object catch (error) {
      // Preserve direct same-network calls during a temporary API/configuration
      // outage. Production cross-NAT calls still require the backend TURN data.
      debugPrint('TURN configuration unavailable; using STUN fallback: $error');
      return CallIceConfiguration.fallback.toPeerConnectionConfiguration();
    }
  }

  void _cancelDisconnectGrace() {
    _disconnectGraceTimer?.cancel();
    _disconnectGraceTimer = null;
  }

  void _emitIce(RTCIceCandidate candidate) {
    final socket = _socket;
    final callId = _callId;
    if (socket == null || callId == null) return;
    socket.emit('call:ice', {'callId': callId, 'candidate': candidate.toMap()});
  }

  void _drainPendingLocalIce() {
    if (_socket == null || _callId == null) return;
    for (final candidate in _pendingLocalIce) {
      _emitIce(candidate);
    }
    _pendingLocalIce.clear();
  }

  void _failCall() {
    // Closing the peer connection during a normal local/remote hang-up may
    // synchronously report `failed` before the native close completes. The
    // call is already being finalized in that case; emitting call:fail would
    // race call:end and could downgrade a successful call to `failed`.
    if (_teardownTask != null || state.value == CallState.ended) return;
    final socket = _socket;
    final callId = _callId;
    if (socket != null && callId != null) {
      socket.emit('call:fail', {'callId': callId});
    }
    _teardown(CallState.ended);
  }

  Future<void> _handleRemoteIce(dynamic data) async {
    if (data is! Map) return;
    final c = data['candidate'];
    if (c is! Map) return;
    _queueRemoteCandidate(c);
    if (_pc != null) await _drainPendingIce();
  }

  void _queueRemoteCandidate(Map<dynamic, dynamic> c) {
    final candidate = RTCIceCandidate(
      c['candidate'] as String?,
      c['sdpMid'] as String?,
      (c['sdpMLineIndex'] as num?)?.toInt(),
    );
    _pendingRemoteIce.add(candidate);
  }

  Future<void> _drainPendingIce() async {
    // Socket.IO may deliver several candidates while an earlier addCandidate
    // call is still awaiting the native WebRTC layer. Serialize drains and
    // detach each batch before awaiting so the event handler can safely append
    // the next candidates without mutating the list being iterated.
    final previous = _remoteIceDrainTask;
    late final Future<void> task;
    task = () async {
      if (previous != null) {
        try {
          await previous;
        } on Object {
          // The original caller observes the failure. Keep the chain usable so
          // teardown/recovery does not strand subsequently received candidates.
        }
      }

      final pc = _pc;
      if (pc == null || _pendingRemoteIce.isEmpty) return;
      final pending = List<RTCIceCandidate>.of(_pendingRemoteIce);
      _pendingRemoteIce.removeRange(0, pending.length);
      for (final candidate in pending) {
        await pc.addCandidate(candidate);
      }
    }();
    _remoteIceDrainTask = task;
    try {
      await task;
    } finally {
      if (identical(_remoteIceDrainTask, task)) {
        _remoteIceDrainTask = null;
      }
    }
  }

  Future<void> _teardown(CallState finalState) async {
    final running = _teardownTask;
    if (running != null) return running;
    final task = _performTeardown(finalState);
    _teardownTask = task;
    try {
      await task;
    } finally {
      if (identical(_teardownTask, task)) _teardownTask = null;
    }
  }

  Future<void> _performTeardown(CallState finalState) async {
    _cancelDisconnectGrace();
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
    state.value = finalState;
    final callId = _callId;
    final callUuid = _callUuid;
    final kind = _kind;
    final recordingOwnerId = _recordingOwnerId;
    final wasActive = _activeSince != null;
    final recordingPath = await _stopRecording();
    for (final track
        in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _pc?.close();
    _localStream = null;
    _pc = null;
    _activeSince = null;
    _callId = null;
    _callUuid = null;
    _recordingOwnerId = null;
    _pendingOffer = null;
    _pendingLocalIce.clear();
    _pendingRemoteIce.clear();
    _muted = false;
    if (callUuid != null) {
      unawaited(FlutterCallkitIncoming.endCall(callUuid));
    }
    if (_speakerOn) {
      _speakerOn = false;
      unawaited(Helper.setSpeakerphoneOn(false));
    }
    if (recordingPath != null &&
        callId != null &&
        kind != null &&
        recordingOwnerId != null &&
        wasActive) {
      try {
        await _recordingQueue.persist(
          kind: kind,
          ownerId: recordingOwnerId,
          callId: callId,
          sourcePath: recordingPath,
        );
        unawaited(retryPendingRecordings());
      } on Object catch (error) {
        // Keep the original temporary file if durable persistence itself fails.
        // It must never be deleted merely because storage/network is unhealthy.
        debugPrint(
          'Call recording could not enter retry queue: '
          'call=$callId kind=$kind $error',
        );
      }
    } else if (recordingPath != null) {
      unawaited(_deleteRecordingFile(recordingPath));
    }
    if (finalState == CallState.idle) {
      statusMessage.value = null;
      return;
    }
    // Keep "Line busy" visible long enough to be understood, then close.
    final resetDelay = finalState == CallState.busy
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 600);
    Future.delayed(resetDelay, () {
      if (state.value == finalState) {
        state.value = CallState.idle;
        statusMessage.value = null;
      }
    });
  }

  void _ensureRecordingStarted() {
    if (_recordingStartTask != null ||
        _androidRecorder != null ||
        _iosRecorder != null ||
        _callId == null ||
        _kind == null) {
      return;
    }
    final callId = _callId!;
    final kind = _kind!;
    late final Future<void> task;
    task = _startRecording(callId, kind).whenComplete(() {
      if (identical(_recordingStartTask, task)) _recordingStartTask = null;
    });
    _recordingStartTask = task;
    unawaited(
      task.catchError((Object error, StackTrace stackTrace) {
        debugPrint('Call recording could not start: $error');
      }),
    );
  }

  Future<void> _startRecording(int callId, String kind) async {
    final ownerId = _session.subjectId;
    if (ownerId == null) {
      throw StateError('Authenticated recording owner is unavailable');
    }
    final path =
        '${Directory.systemTemp.path}/fixleo-call-$callId-$kind-'
        '${DateTime.now().microsecondsSinceEpoch}.m4a';
    _recordingPath = path;
    _recordingOwnerId = ownerId;
    try {
      if (Platform.isAndroid) {
        // Uses flutter_webrtc's own captured PCM samples; opening a second
        // Android microphone session would interrupt or silence the live call.
        final recorder = MediaRecorder();
        _androidRecorder = recorder;
        await recorder.start(path, audioChannel: RecorderAudioChannel.INPUT);
      } else if (Platform.isIOS) {
        final recorder = AudioRecorder();
        _iosRecorder = recorder;
        if (!await recorder.hasPermission(request: false)) {
          throw StateError('Microphone permission is unavailable');
        }
        // WebRTC already owns/configures AVAudioSession. The recorder must
        // observe it, not replace its play-and-record routing.
        await recorder.ios?.manageAudioSession(false);
        await recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 48000,
            numChannels: 1,
            audioInterruption: AudioInterruptionMode.pauseResume,
          ),
          path: path,
        );
      } else {
        throw UnsupportedError(
          'Call recording is supported on Android and iOS',
        );
      }
      debugPrint('Call recording started: call=$callId kind=$kind');
    } on Object {
      _androidRecorder = null;
      final iosRecorder = _iosRecorder;
      _iosRecorder = null;
      await iosRecorder?.dispose();
      _recordingPath = null;
      _recordingOwnerId = null;
      await _deleteRecordingFile(path);
      rethrow;
    }
  }

  Future<String?> _stopRecording() async {
    final startTask = _recordingStartTask;
    if (startTask != null) {
      try {
        await startTask;
      } on Object {
        // Start failure has already cleaned up and is logged by its owner.
      }
    }

    final path = _recordingPath;
    final androidRecorder = _androidRecorder;
    final iosRecorder = _iosRecorder;
    _androidRecorder = null;
    _iosRecorder = null;
    _recordingPath = null;
    try {
      if (androidRecorder != null) {
        await androidRecorder.stop();
      }
      if (iosRecorder != null) {
        await iosRecorder.stop();
      }
    } on Object catch (error) {
      debugPrint('Call recording could not stop cleanly: $error');
    } finally {
      await iosRecorder?.dispose();
    }

    if (path == null) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() < 12) {
      await _deleteRecordingFile(path);
      return null;
    }
    return path;
  }

  /// Retries all recordings owned by the active account. Failed uploads keep
  /// both metadata and audio with exponential backoff; success is the only
  /// normal path that deletes the local file.
  Future<void> retryPendingRecordings() {
    final active = _recordingRetryTask;
    if (active != null) {
      // A new recording may have been persisted after the active drain loaded
      // its snapshot. Run one more drain when it finishes so that item is not
      // stranded until another app lifecycle event.
      _recordingRetryRequested = true;
      return active;
    }
    final task = _drainRecordingQueue();
    _recordingRetryTask = task;
    return task.whenComplete(() {
      if (identical(_recordingRetryTask, task)) {
        _recordingRetryTask = null;
        if (_recordingRetryRequested) {
          _recordingRetryRequested = false;
          unawaited(retryPendingRecordings());
        }
      }
    });
  }

  Future<void> _drainRecordingQueue() async {
    final role = _session.role;
    final ownerId = _session.subjectId;
    if (!_session.isLoggedIn ||
        ownerId == null ||
        (role != AuthRole.client && role != AuthRole.master)) {
      return;
    }
    final kind = role!.name;
    final pending = await _recordingQueue.pendingFor(
      kind: kind,
      ownerId: ownerId,
    );
    final now = DateTime.now().toUtc();

    for (final item in pending) {
      if (_session.role?.name != kind || _session.subjectId != ownerId) return;
      final nextAttemptAt = item.nextAttemptAt?.toUtc();
      if (nextAttemptAt != null && nextAttemptAt.isAfter(now)) {
        _scheduleRecordingRetry(nextAttemptAt);
        continue;
      }

      try {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            item.path,
            filename: 'call-${item.callId}-${item.kind}.m4a',
          ),
        });
        await ApiClient.instance.postMultipart(
          '/${item.kind}s/me/calls/${item.callId}/recording',
          form,
        );
        await _recordingQueue.complete(item);
        debugPrint(
          'Call recording uploaded: call=${item.callId} kind=${item.kind}',
        );
      } on Object catch (error) {
        final updated = await _recordingQueue.markFailed(item);
        _scheduleRecordingRetry(updated.nextAttemptAt!);
        debugPrint(
          'Call recording upload queued for retry: '
          'call=${item.callId} kind=${item.kind} '
          'attempt=${updated.attempts} $error',
        );
      }
    }
  }

  void _scheduleRecordingRetry(DateTime at) {
    final target = at.toUtc();
    final current = _recordingRetryAt;
    if (_recordingRetryTimer?.isActive == true &&
        current != null &&
        !target.isBefore(current)) {
      return;
    }
    _recordingRetryTimer?.cancel();
    _recordingRetryAt = target;
    final delay = target.difference(DateTime.now().toUtc());
    _recordingRetryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _recordingRetryAt = null;
      unawaited(retryPendingRecordings());
    });
  }

  Future<void> _deleteRecordingFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object {
      // Temporary-file cleanup is best effort.
    }
  }

  /// Fully disconnect the signalling socket (e.g. on logout).
  void disconnect() {
    _teardown(CallState.idle);
    _socket?.dispose();
    _socket = null;
    _kind = null;
    _connectedOwnerId = null;
    _onIncoming = null;
    _recordingRetryTimer?.cancel();
    _recordingRetryTimer = null;
    _recordingRetryAt = null;
    _recordingRetryRequested = false;
  }

  void endIncomingFromRemote(String callUuid) {
    if (_callUuid == null ||
        _callUuid!.toLowerCase() == callUuid.toLowerCase()) {
      _teardown(CallState.ended);
    }
  }
}
