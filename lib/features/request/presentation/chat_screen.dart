import 'package:fixleo/app/widgets/app_feedback.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/location/device_location_service.dart';
import 'package:fixleo/core/location/reverse_geocoder.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/notifications/native_call_service.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/core/realtime/chat_socket.dart';
import 'package:fixleo/core/permissions/permission_prompt.dart';
import 'package:fixleo/features/calls/presentation/call_screen.dart';
import 'package:fixleo/features/request/data/chat_service.dart' as api_chat;
import 'package:fixleo/features/request/presentation/attach_photos_sheet.dart';
import 'package:fixleo/features/request/presentation/client_info_screen.dart';
import 'package:fixleo/features/request/presentation/master_profile_screen.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_media_message.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_message_surface.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_peer_avatar.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_presence_text.dart';

/// A single chat message bubble. [isMine] is true for the user's own (blue)
/// bubbles. (Kept as a lightweight display model; the wire model lives in
/// [api_chat.ChatMessage].)
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.type,
    required this.text,
    required this.time,
    required this.isMine,
    required this.isRead,
    this.imageUrl,
    this.audioUrl,
    this.durationSec,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.createdAt,
  });

  final int id;
  final String type;
  final String text;
  final String time;
  final bool isMine;
  final bool isRead;
  final String? imageUrl;
  final String? audioUrl;
  final int? durationSec;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final DateTime? createdAt;

  ChatMessage copyWith({bool? isRead}) {
    return ChatMessage(
      id: id,
      type: type,
      text: text,
      time: time,
      isMine: isMine,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      durationSec: durationSec,
      latitude: latitude,
      longitude: longitude,
      locationLabel: locationLabel,
      createdAt: createdAt,
    );
  }
}

enum _ImageUploadStatus { uploading, failed }

/// REST snapshots and socket events can arrive in either order. Keep IDs unique
/// and read state monotonic, including a receipt arriving before send returns.
List<ChatMessage> mergeChatMessages(
  Iterable<ChatMessage> current,
  Iterable<ChatMessage> incoming, {
  int readUpTo = 0,
}) {
  final byId = {for (final message in current) message.id: message};
  for (final message in incoming) {
    byId[message.id] = message.copyWith(
      isRead:
          message.isRead ||
          byId[message.id]?.isRead == true ||
          (message.isMine && message.id <= readUpTo),
    );
  }
  return byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

class _ImageUpload {
  _ImageUpload(this.file);

  final XFile file;
  double progress = 0;
  _ImageUploadStatus status = _ImageUploadStatus.uploading;
}

/// One-on-one order chat — live thread + working input bar (docs/v3/Chat.md).
/// Reused by both the client side (chatting with the master) and the master
/// side; [kind] picks the `/clients` or `/masters` endpoint prefix.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.peerName,
    this.peerAvatarUrl,
    this.kind = 'client',
  });

  final int conversationId;
  final String? peerName;
  final String? peerAvatarUrl;
  final String kind; // 'client' | 'master'

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const _bubbleText = Color(0xFF23232E);
  static const _incomingTime = Color(0xFF9494A3);
  static const _slate500 = Color(0xFF64748B);

  late final api_chat.ChatService _service = api_chat.ChatService(
    kind: widget.kind,
  );
  late final ChatSocket _chatSocket = ChatSocket(
    kind: widget.kind,
    conversationId: widget.conversationId,
  );
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _recorder = AudioRecorder();
  final _locationService = DeviceLocationService();
  final _reverseGeocoder = ReverseGeocoder();

  final List<ChatMessage> _messages = [];
  final Set<int> _enteringMessages = {};
  final List<_ImageUpload> _imageUploads = [];
  bool _loading = true;
  bool _sending = false;
  bool _hasText = false;
  int _readUpTo = 0;
  int _acknowledgedIncomingId = 0;
  bool _reading = false;
  bool _loadingMessages = false;
  bool _reloadRequested = false;
  bool _foreground = true;
  Timer? _readRetry;
  int _readRetries = 0;
  bool _recording = false;
  bool _startingRecording = false;
  bool _finishingRecording = false;
  Duration _recordingDuration = Duration.zero;
  DateTime? _recordingStartedAt;
  Timer? _recordingTimer;
  StreamSubscription<PresenceUpdate>? _presenceSubscription;

  /// Peer presence from the conversation endpoint; null until loaded.
  bool? _peerOnline;
  DateTime? _peerLastSeenAt;
  String? _peerName;
  String? _peerAvatarUrl;
  String? _peerPhone;

  /// The peer's own account id — needed to open their full profile.
  int? _peerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onChatScroll);
    _peerName = widget.peerName;
    _peerAvatarUrl = widget.peerAvatarUrl;
    NativeCallService.instance.setActiveConversation(widget.conversationId);
    _controller.addListener(_onTextChanged);
    _load();
    _loadPresence();
    _presenceSubscription = AppPresenceService.instance.updates.listen((
      update,
    ) {
      if (!mounted || update.conversationId != widget.conversationId) return;
      setState(() {
        _peerOnline = update.online;
        _peerLastSeenAt = update.lastSeenAt;
      });
    });
    // Live incoming messages — append the peer's messages as they arrive so the
    // thread updates without a reopen. (Own messages are shown locally on send.)
    _chatSocket.connect(
      (m) {
        if (!mounted) return;
        final follow = _atBottom;
        setState(() => _merge([_toBubble(m)]));
        if (follow) _scrollToBottom();
        _readRetries = 0;
        _scheduleRead();
      },
      onRead: _markOutgoingMessagesRead,
      onConnected: () => unawaited(_load()),
    );
    // Voice-call signalling: ensure connected (home already connects it app-wide).
    CallService.instance.connect(widget.kind);
    CallService.instance.state.addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    if (mounted && CallService.instance.state.value == CallState.idle) {
      unawaited(_load());
    }
  }

  void _openCallScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CallScreen(),
      ),
    );
  }

  Future<void> _startCall() async {
    if (!await _ensureMicrophonePermission()) return;
    final call = CallService.instance;
    await call.startCall(
      widget.conversationId,
      displayName: _peerName,
      avatarUrl: _peerAvatarUrl,
    );
    if (mounted && call.isBusy) _openCallScreen();
  }

  /// Tapping the header now opens the peer's full profile — a browsable
  /// master profile (rating, bio, reviews, work photos) for clients, or a
  /// lighter client-info screen for masters (clients don't have that kind of
  /// public profile) — instead of just a zoomable photo.
  Future<void> _openPeerProfile() async {
    if (widget.kind == 'client') {
      if (_peerId == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MasterProfileScreen(masterId: _peerId!),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientInfoScreen(
            name: _peerName ?? tr(_lang, 'Mijoz', 'Клиент', 'Client'),
            avatarUrl: _peerAvatarUrl,
            phone: _peerPhone,
            online: _peerOnline,
            lastSeenAt: _peerLastSeenAt,
          ),
        ),
      );
    }
    if (mounted) unawaited(_load());
  }

  AppLanguage get _lang => LocaleController.language.value;

  Future<void> _loadPresence() async {
    try {
      final conv = await _service.conversation(widget.conversationId);
      if (mounted) {
        setState(() {
          _peerOnline = conv.peerOnline;
          _peerLastSeenAt = conv.peerLastSeenAt;
          _peerName = conv.peerName ?? _peerName;
          _peerAvatarUrl = conv.peerAvatarUrl ?? _peerAvatarUrl;
          _peerPhone = conv.peerPhone ?? _peerPhone;
          _peerId = conv.peerId ?? _peerId;
        });
      }
    } on ApiException {
      // Keep the header without a presence line.
    }
  }

  Future<void> _load() async {
    if (_loadingMessages) {
      _reloadRequested = true;
      return;
    }
    _loadingMessages = true;
    final follow = _loading || _atBottom;
    try {
      final msgs = await _service.messages(widget.conversationId, limit: 50);
      if (!mounted) return;
      setState(() {
        _merge(msgs.map(_toBubble));
        _loading = false;
      });
      if (follow) _scrollToBottom(immediate: true);
      _scheduleRead();
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    } finally {
      _loadingMessages = false;
      if (_reloadRequested && mounted) {
        _reloadRequested = false;
        unawaited(_load());
      }
    }
  }

  void _merge(Iterable<ChatMessage> incoming) {
    if (!_loading) {
      final existing = _messages.map((m) => m.id).toSet();
      _enteringMessages.addAll(
        incoming.where((m) => !existing.contains(m.id)).map((m) => m.id),
      );
    }
    final merged = mergeChatMessages(_messages, incoming, readUpTo: _readUpTo);
    _messages
      ..clear()
      ..addAll(merged);
  }

  bool get _atBottom =>
      !_scrollController.hasClients || _scrollController.offset <= 48;
  bool get _canRead =>
      mounted &&
      _foreground &&
      ModalRoute.of(context)?.isCurrent == true &&
      _atBottom;

  void _onChatScroll() {
    if (_atBottom) _scheduleRead();
  }

  void _scheduleRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canRead) unawaited(_acknowledgeRead());
    });
  }

  Future<void> _acknowledgeRead() async {
    if (!_canRead || _reading) return;
    final incoming = _messages.where((m) => !m.isMine);
    if (incoming.isEmpty) return;
    final target = incoming.last.id;
    if (target <= _acknowledgedIncomingId) return;
    _reading = true;
    var succeeded = false;
    try {
      await _service.markRead(widget.conversationId, upToMessageId: target);
      _acknowledgedIncomingId = target;
      _readRetries = 0;
      succeeded = true;
    } catch (_) {
      if (mounted && _readRetries++ < 3) {
        _readRetry?.cancel();
        _readRetry = Timer(
          const Duration(seconds: 2),
          () => unawaited(_acknowledgeRead()),
        );
      }
    } finally {
      _reading = false;
    }
    if (succeeded && mounted) unawaited(_acknowledgeRead());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _readRetries = 0;
      unawaited(_load());
      unawaited(_loadPresence());
    }
  }

  ChatMessage _toBubble(api_chat.ChatMessage m) {
    // .toLocal() — createdAt comes from the backend as UTC; without this the
    // bubble showed the UTC hour (e.g. "12:24" at 17:24 local in Tashkent,
    // UTC+5) instead of the device's actual wall-clock time.
    final t = m.createdAt?.toLocal();
    final time = t == null
        ? ''
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final text = switch (m.type) {
      'call' => '📞 ${formatChatDuration(m.callDurationSec ?? 0)}',
      _ => m.text ?? '',
    };
    return ChatMessage(
      id: m.id,
      type: m.type,
      text: text,
      time: time,
      isMine: m.sender == widget.kind,
      isRead: m.readAt != null,
      imageUrl: m.imageUrl,
      audioUrl: m.audioUrl,
      durationSec: m.type == 'call' ? m.callDurationSec : m.voiceDurationSec,
      latitude: m.latitude,
      longitude: m.longitude,
      locationLabel: m.locationLabel,
      createdAt: m.createdAt,
    );
  }

  void _markOutgoingMessagesRead(int? upToMessageId) {
    if (!mounted) return;
    final watermark =
        upToMessageId ?? (_messages.isEmpty ? 0 : _messages.last.id);
    if (watermark > _readUpTo) _readUpTo = watermark;
    var changed = false;
    final updated = _messages
        .map((message) {
          final isCovered =
              message.isMine &&
              !message.isRead &&
              (upToMessageId == null || message.id <= upToMessageId);
          if (!isCovered) return message;
          changed = true;
          return message.copyWith(isRead: true);
        })
        .toList(growable: false);
    if (changed) {
      setState(() {
        _messages
          ..clear()
          ..addAll(updated);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readRetry?.cancel();
    _scrollController.removeListener(_onChatScroll);
    NativeCallService.instance.clearActiveConversation(widget.conversationId);
    CallService.instance.state.removeListener(_onCallStateChanged);
    unawaited(_presenceSubscription?.cancel());
    _chatSocket.disconnect();
    _recordingTimer?.cancel();
    if (_recording) {
      unawaited(_recorder.stop());
    }
    unawaited(_recorder.dispose());
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool immediate = false}) {
    unawaited(_settleAtBottom(immediate: immediate));
  }

  /// A reversed timeline anchors new/media messages at offset zero. No delayed
  /// jumps compete with the user's drag or with another incoming message.
  Future<void> _settleAtBottom({required bool immediate}) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) return;
    if (immediate || MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(0);
    } else {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
    _scheduleRead();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      final sent = await _service.sendText(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        _merge([_toBubble(sent)]);
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_controller.text.isEmpty) _controller.text = text;
      setState(() => _sending = false);
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (mounted && hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (_sending || _recording) return;
    final action = await showChatAttachmentSheet(context);
    if (action == null || !mounted) return;
    if (action == ChatAttachmentAction.currentLocation) {
      await _shareCurrentLocation();
      return;
    }
    await _pickAndSendImages(
      action == ChatAttachmentAction.gallery
          ? ImageSource.gallery
          : ImageSource.camera,
    );
  }

  Future<void> _pickAndSendImages(ImageSource source) async {
    try {
      final List<XFile> files;
      if (source == ImageSource.gallery) {
        files = await _imagePicker.pickMultiImage(
          imageQuality: 88,
          maxWidth: 2200,
          limit: 3,
        );
      } else {
        final file = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 88,
          maxWidth: 2200,
        );
        files = file == null ? const [] : [file];
      }
      if (files.isEmpty || !mounted) return;

      final uploads = files.take(3).map(_ImageUpload.new).toList();
      setState(() {
        _imageUploads
          ..clear()
          ..addAll(uploads);
        _sending = true;
      });
      final results = await Future.wait(uploads.map(_uploadImage));
      if (!mounted) return;
      setState(() => _sending = false);
      if (results.any((sent) => !sent)) {
        final lang = LocaleController.language.value;
        _showError(
          tr(
            lang,
            'Ayrim rasmlarni yuborib bo‘lmadi. Ularni qayta yuborishingiz mumkin.',
            'Некоторые фото не отправились. Их можно отправить повторно.',
            'Some photos could not be sent. You can retry them.',
          ),
        );
      }
    } on Object {
      final lang = LocaleController.language.value;
      _showError(
        tr(
          lang,
          'Rasmni yuborib bo‘lmadi. Qayta urinib ko‘ring.',
          'Не удалось отправить фото. Попробуйте снова.',
          'Could not send the photo. Please try again.',
        ),
      );
    }
  }

  Future<void> _shareCurrentLocation() async {
    final lang = LocaleController.language.value;
    late final DeviceLocationPermissionState permission;
    try {
      permission = await _locationService.permissionState();
    } on Object {
      _showLocationFailure(DeviceLocationFailure.unavailable);
      return;
    }
    if (!mounted) return;
    if (permission == DeviceLocationPermissionState.deniedForever) {
      _showLocationFailure(DeviceLocationFailure.permissionDeniedForever);
      return;
    }
    if (permission != DeviceLocationPermissionState.granted) {
      final shouldContinue = await showPermissionRationale(
        context,
        icon: Icons.my_location_rounded,
        titleUz: 'Joylashuvni yuborish',
        titleRu: 'Отправить местоположение',
        titleEn: 'Share location',
        messageUz:
            'Fixleo faqat hozirgi joylashuvingizni bir marta aniqlab, suhbatdoshingizga yuboradi. Live kuzatuv yoqilmaydi.',
        messageRu:
            'Fixleo определит ваше текущее местоположение один раз и отправит его собеседнику. Отслеживание в реальном времени не включается.',
        messageEn:
            'Fixleo will determine your current location once and send it to the other participant. Live tracking is not enabled.',
      );
      if (!shouldContinue || !mounted) return;
    }

    setState(() => _sending = true);
    try {
      final point = await _locationService.currentLocation();
      String? label;
      try {
        final result = await _reverseGeocoder.resolve(point);
        if (result != null) {
          label = <String>{
            result.label.trim(),
            result.subtitle.trim(),
          }.where((part) => part.isNotEmpty).join(', ');
        }
      } on Object {
        // Coordinates are sufficient when reverse geocoding is unavailable.
      }
      final sent = await _service.sendLocation(
        widget.conversationId,
        latitude: point.latitude,
        longitude: point.longitude,
        label: label,
      );
      if (!mounted) return;
      setState(() {
        _merge([_toBubble(sent)]);
        _sending = false;
      });
      _scrollToBottom();
    } on DeviceLocationException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showLocationFailure(error.failure);
    } on ApiException catch (error) {
      _showError(error.message);
    } on Object {
      _showError(
        tr(
          lang,
          'Joylashuvni yuborib bo‘lmadi. Qayta urinib ko‘ring.',
          'Не удалось отправить местоположение. Попробуйте снова.',
          'Could not send the location. Please try again.',
        ),
      );
    } finally {
      if (mounted && _sending) setState(() => _sending = false);
    }
  }

  void _showLocationFailure(DeviceLocationFailure failure) {
    if (!mounted) return;
    final lang = LocaleController.language.value;
    final needsAppSettings =
        failure == DeviceLocationFailure.permissionDeniedForever;
    final needsLocationSettings =
        failure == DeviceLocationFailure.serviceDisabled;
    final message = switch (failure) {
      DeviceLocationFailure.serviceDisabled => tr(
        lang,
        'Telefon joylashuv xizmati o‘chirilgan.',
        'Служба геолокации телефона выключена.',
        'The phone location service is turned off.',
      ),
      DeviceLocationFailure.permissionDeniedForever => tr(
        lang,
        'Joylashuv ruxsati bloklangan. Uni sozlamalardan yoqing.',
        'Доступ к геолокации заблокирован. Включите его в настройках.',
        'Location permission is blocked. Enable it in Settings.',
      ),
      DeviceLocationFailure.permissionDenied => tr(
        lang,
        'Joylashuvga ruxsat berilmadi.',
        'Доступ к геолокации не предоставлен.',
        'Location permission was not granted.',
      ),
      DeviceLocationFailure.timeout => tr(
        lang,
        'Joylashuvni aniqlash uzoq davom etdi. Qayta urinib ko‘ring.',
        'Определение местоположения заняло слишком много времени. Попробуйте снова.',
        'Determining the location took too long. Please try again.',
      ),
      DeviceLocationFailure.unavailable => tr(
        lang,
        'Joriy joylashuvni aniqlab bo‘lmadi.',
        'Не удалось определить текущее местоположение.',
        'Could not determine the current location.',
      ),
    };
    AppFeedback.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: needsAppSettings || needsLocationSettings
            ? SnackBarAction(
                label: tr(lang, 'Sozlamalar', 'Настройки', 'Settings'),
                onPressed: () {
                  if (needsAppSettings) {
                    _locationService.openAppSettings();
                  } else {
                    _locationService.openLocationSettings();
                  }
                },
              )
            : null,
      ),
    );
  }

  Future<bool> _uploadImage(_ImageUpload upload) async {
    try {
      final sent = await _service.sendImage(
        widget.conversationId,
        upload.file.path,
        onSendProgress: (sentBytes, totalBytes) {
          if (!mounted || totalBytes <= 0) return;
          setState(() {
            upload.progress = (sentBytes / totalBytes).clamp(0, 1);
          });
        },
      );
      if (!mounted) return false;
      setState(() {
        _imageUploads.remove(upload);
        _merge([_toBubble(sent)]);
      });
      _scrollToBottom();
      return true;
    } on Object {
      if (!mounted) return false;
      setState(() => upload.status = _ImageUploadStatus.failed);
      return false;
    }
  }

  Future<void> _retryImageUpload(_ImageUpload upload) async {
    if (_sending || upload.status != _ImageUploadStatus.failed) return;
    setState(() {
      upload
        ..progress = 0
        ..status = _ImageUploadStatus.uploading;
      _sending = true;
    });
    final sent = await _uploadImage(upload);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!sent) {
      final lang = LocaleController.language.value;
      _showError(
        tr(
          lang,
          'Rasmni yuborib bo‘lmadi. Qayta urinib ko‘ring.',
          'Не удалось отправить фото. Попробуйте снова.',
          'Could not send the photo. Please try again.',
        ),
      );
    }
  }

  void _removeFailedUpload(_ImageUpload upload) {
    if (upload.status != _ImageUploadStatus.failed) return;
    setState(() => _imageUploads.remove(upload));
  }

  Future<void> _startRecording() async {
    if (_sending || _recording || _startingRecording || _finishingRecording) {
      return;
    }
    final lang = LocaleController.language.value;
    if (CallService.instance.isBusy) {
      _showError(
        tr(
          lang,
          'Qo‘ng‘iroq vaqtida ovozli xabar yozib bo‘lmaydi.',
          'Во время звонка нельзя записать голосовое сообщение.',
          'A voice message cannot be recorded during a call.',
        ),
      );
      return;
    }
    setState(() => _startingRecording = true);
    try {
      final hasPermission = await _ensureMicrophonePermission();
      if (!hasPermission) {
        _showError(
          tr(
            lang,
            'Mikrofonga ruxsat bering.',
            'Разрешите доступ к микрофону.',
            'Allow microphone access.',
          ),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/fixleo-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordingStartedAt = DateTime.now();
        _recordingDuration = Duration.zero;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final startedAt = _recordingStartedAt;
        if (!mounted || !_recording || startedAt == null) return;
        final duration = DateTime.now().difference(startedAt);
        setState(() => _recordingDuration = duration);
        if (duration.inSeconds >= 15 * 60) {
          unawaited(_finishRecording(send: true));
        }
      });
    } on Object {
      _showError(
        tr(
          lang,
          'Ovoz yozishni boshlab bo‘lmadi.',
          'Не удалось начать запись.',
          'Could not start recording.',
        ),
      );
    } finally {
      if (mounted) setState(() => _startingRecording = false);
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final alreadyGranted = await _recorder
        .hasPermission(request: false)
        .timeout(const Duration(seconds: 3), onTimeout: () => false);
    if (alreadyGranted) return true;
    if (!mounted) return false;
    final shouldContinue = await showPermissionRationale(
      context,
      icon: Icons.mic_none_rounded,
      titleUz: 'Mikrofonga ruxsat',
      titleRu: 'Доступ к микрофону',
      titleEn: 'Microphone permission',
      messageUz:
          'Fixleo ovozli xabar yozish va qo‘ng‘iroqda suhbatlashish uchun mikrofondan foydalanadi. Mikrofon faqat siz boshlagan paytda yoqiladi.',
      messageRu:
          'Fixleo использует микрофон для голосовых сообщений и звонков. Микрофон включается только после вашего действия.',
      messageEn:
          'Fixleo uses the microphone for voice messages and calls. It is activated only after you start one of these actions.',
    );
    if (!shouldContinue) return false;
    return _recorder.hasPermission().timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_recording || _finishingRecording) return;
    _finishingRecording = true;
    _recordingTimer?.cancel();
    final durationSec = _recordingDuration.inSeconds;
    try {
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          _recording = false;
          _recordingStartedAt = null;
          _recordingDuration = Duration.zero;
        });
      }
      if (path == null) return;
      if (!send || durationSec < 1) {
        await _deleteTempFile(path);
        return;
      }
      if (mounted) setState(() => _sending = true);
      final sent = await _service.sendVoice(
        widget.conversationId,
        path,
        durationSec,
      );
      if (!mounted) return;
      setState(() {
        _merge([_toBubble(sent)]);
        _sending = false;
      });
      _scrollToBottom();
      await _deleteTempFile(path);
    } on ApiException catch (error) {
      _showError(error.message);
    } on Object {
      final lang = LocaleController.language.value;
      _showError(
        tr(
          lang,
          'Ovozli xabarni yuborib bo‘lmadi.',
          'Не удалось отправить голосовое сообщение.',
          'Could not send the voice message.',
        ),
      );
    } finally {
      _finishingRecording = false;
      if (mounted && _sending) setState(() => _sending = false);
    }
  }

  Future<void> _deleteTempFile(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // The recorder/platform may already have removed its temporary file.
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    if (_sending) setState(() => _sending = false);
    AppFeedback.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      // Keep the original header/background; repeated message bubbles remain flat.
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(context, lang),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.waving_hand_outlined,
                                size: 36,
                                color: AppColors.blue,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tr(
                                  lang,
                                  'Suhbatni boshlang',
                                  'Начните беседу',
                                  'Start a conversation',
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr(
                                  lang,
                                  'Tafsilotlarni kelishib oling, rasm yoki joylashuv yuboring.',
                                  'Обсудите детали, отправьте фото или местоположение.',
                                  'Discuss the details, share a photo or a location.',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _slate500,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 3),
                        itemCount: _messages.length,
                        findChildIndexCallback: (key) {
                          if (key is! ValueKey<int>) return null;
                          final index = _messages.indexWhere(
                            (m) => m.id == key.value,
                          );
                          return index < 0
                              ? null
                              : _messages.length - 1 - index;
                        },
                        itemBuilder: (context, index) {
                          final messageIndex = _messages.length - 1 - index;
                          final id = _messages[messageIndex].id;
                          return TweenAnimationBuilder<double>(
                            key: ValueKey<int>(id),
                            tween: Tween(
                              begin: _enteringMessages.contains(id) ? 0 : 1,
                              end: 1,
                            ),
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 160),
                            onEnd: () => _enteringMessages.remove(id),
                            child: _messageItem(messageIndex),
                            builder: (_, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 6 * (1 - value)),
                                child: child,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_imageUploads.isNotEmpty) _imageUploadStrip(lang),
              _inputBar(lang),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppLanguage lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GlassIconButton(
            onTap: () => Navigator.of(context).maybePop(),
            semanticLabel: tr(lang, 'Orqaga', 'Назад', 'Back'),
            child: const Icon(
              Icons.arrow_back,
              size: 20,
              color: AppColors.navy,
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _openPeerProfile,
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  borderRadius: 30,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatPeerAvatar(imageUrl: _peerAvatarUrl, size: 36),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _peerName ?? tr(lang, 'Suhbat', 'Чат', 'Chat'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 22 / 16,
                                letterSpacing: -0.18,
                                fontWeight: FontWeight.w700,
                                color: _bubbleText,
                              ),
                            ),
                            Text(
                              _peerOnline == null
                                  ? tr(
                                      lang,
                                      'holat aniqlanmoqda',
                                      'статус загружается',
                                      'checking status',
                                    )
                                  : _peerOnline!
                                  ? tr(lang, 'onlayn', 'в сети', 'online')
                                  : tr(lang, 'oflayn', 'не в сети', 'offline'),
                              style: TextStyle(
                                fontSize: 13,
                                height: 17 / 13,
                                letterSpacing: -0.14,
                                color: _peerOnline == true
                                    ? AppColors.blue
                                    : const Color(0xFF8D96A4),
                              ),
                            ),
                            Text(
                              formatLastSeenLabel(lang, _peerLastSeenAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 15 / 11,
                                color: Color(0xFF8D96A4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GlassIconButton(
            onTap: _startCall,
            semanticLabel: tr(lang, 'Qoʻngʻiroq', 'Позвонить', 'Call'),
            child: const Icon(
              Icons.phone_outlined,
              size: 20,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageItem(int index) {
    final m = _messages[index];
    final previous = index > 0 ? _messages[index - 1] : null;
    final next = index + 1 < _messages.length ? _messages[index + 1] : null;
    final startsDay =
        m.createdAt != null &&
        (previous?.createdAt == null ||
            !DateUtils.isSameDay(
              m.createdAt!.toLocal(),
              previous!.createdAt!.toLocal(),
            ));
    final grouped =
        next != null &&
        next.isMine == m.isMine &&
        DateUtils.isSameDay(next.createdAt?.toLocal(), m.createdAt?.toLocal());
    return Padding(
      key: ValueKey(m.id),
      padding: EdgeInsets.only(bottom: grouped ? 3 : 7),
      child: Column(
        children: [
          if (startsDay) ChatDateDivider(date: m.createdAt!),
          ChatMessageSurface(
            isMine: m.isMine,
            isRead: m.isRead,
            time: m.time,
            isMedia: m.type == 'image' || m.type == 'location',
            grouped: grouped,
            child: _messageBody(m),
          ),
        ],
      ),
    );
  }

  Widget _messageBody(ChatMessage message) {
    if (message.type == 'call') {
      final lang = LocaleController.language.value;
      final foreground = message.isMine ? Colors.white : AppColors.navy;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiquidSurface(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_in_talk_outlined,
              size: 21,
              color: foreground,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(lang, 'Qo‘ng‘iroq', 'Звонок', 'Voice call'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatChatDuration(message.durationSec ?? 0),
                  style: TextStyle(
                    fontSize: 12,
                    color: foreground.withValues(alpha: .75),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (message.type == 'image') {
      final url = message.imageUrl;
      if (url != null) {
        return ChatImageMessage(url: url, isMine: message.isMine);
      }
      return Icon(
        Icons.broken_image_outlined,
        color: message.isMine ? Colors.white70 : _incomingTime,
      );
    }
    if (message.type == 'voice') {
      final url = message.audioUrl;
      if (url != null) {
        return ChatVoiceMessage(
          url: url,
          isMine: message.isMine,
          durationSec: message.durationSec ?? 0,
          playLabel: tr(
            LocaleController.language.value,
            'Eshitish',
            'Воспроизвести',
            'Play',
          ),
          pauseLabel: tr(
            LocaleController.language.value,
            'Pauza',
            'Пауза',
            'Pause',
          ),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic_off_outlined,
            size: 18,
            color: message.isMine ? Colors.white70 : _incomingTime,
          ),
          const SizedBox(width: 6),
          Text(
            formatChatDuration(message.durationSec ?? 0),
            style: TextStyle(
              color: message.isMine ? Colors.white : _bubbleText,
            ),
          ),
        ],
      );
    }
    if (message.type == 'location') {
      final latitude = message.latitude;
      final longitude = message.longitude;
      if (latitude != null && longitude != null) {
        return ChatLocationMessage(
          point: LatLng(latitude, longitude),
          label: message.locationLabel,
          isMine: message.isMine,
        );
      }
      return Icon(
        Icons.location_off_outlined,
        color: message.isMine ? Colors.white70 : _incomingTime,
      );
    }
    return Text(
      message.text,
      style: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: message.isMine ? Colors.white : _bubbleText,
      ),
    );
  }

  /// Bottom input bar: camera, working text field and send button — floating
  /// on the page background like the Figma design.
  Widget _inputBar(AppLanguage lang) {
    if (_recording) return _recordingBar(lang);
    return GlassContainer(
      borderRadius: 30,
      shadow: false,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 5),
      child: Row(
        children: [
          LiquidIconControl(
            child: IconButton(
              tooltip: tr(lang, 'Biriktirish', 'Прикрепить', 'Attach'),
              onPressed: _sending || _startingRecording
                  ? null
                  : _pickAndSendAttachment,
              icon: const Icon(Icons.add_rounded, size: 26, color: _slate500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: _bubbleText,
              ),
              decoration: InputDecoration(
                hintText: tr(
                  lang,
                  'Xabar yozing…',
                  'Напишите сообщение…',
                  'Write a message…',
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFF7C8B9D),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: usesGlassMaterial(context)
                    ? Colors.white.withValues(alpha: .5)
                    : const Color(0xFFF2F5F8),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFB6D8FC)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(
            tooltip: _hasText
                ? tr(lang, 'Yuborish', 'Отправить', 'Send')
                : tr(
                    lang,
                    'Ovozli xabar',
                    'Голосовое сообщение',
                    'Voice message',
                  ),
            onTap: _sending || _startingRecording
                ? null
                : _hasText
                ? _send
                : _startRecording,
            child: (_sending && _imageUploads.isEmpty) || _startingRecording
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _hasText ? Icons.arrow_upward : Icons.mic_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _imageUploadStrip(AppLanguage lang) {
    return LiquidSurface(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: SizedBox(
        height: 82,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _imageUploads.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final upload = _imageUploads[index];
            final failed = upload.status == _ImageUploadStatus.failed;
            final percent = (upload.progress * 100).round();
            return Semantics(
              label: failed
                  ? tr(
                      lang,
                      'Rasm yuborilmadi. Qayta yuborish uchun bosing.',
                      'Фото не отправлено. Нажмите, чтобы повторить.',
                      'Photo failed to send. Tap to retry.',
                    )
                  : tr(
                      lang,
                      'Rasm $percent foiz yuklandi',
                      'Фото загружено на $percent процентов',
                      'Photo upload $percent percent',
                    ),
              button: failed,
              child: GestureDetector(
                onTap: failed ? () => _retryImageUpload(upload) : null,
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(upload.file.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      LiquidDecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      Center(
                        child: failed
                            ? const Icon(
                                Icons.refresh_rounded,
                                size: 30,
                                color: Colors.white,
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 46,
                                    height: 46,
                                    child: CircularProgressIndicator(
                                      value: upload.progress,
                                      strokeWidth: 3,
                                      backgroundColor: Colors.white24,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '$percent%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (failed)
                        Positioned(
                          right: 3,
                          top: 3,
                          child: LiquidIconControl(
                            child: IconButton(
                              tooltip: tr(
                                lang,
                                'Olib tashlash',
                                'Удалить',
                                'Remove',
                              ),
                              onPressed: () => _removeFailedUpload(upload),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(26, 26),
                                maximumSize: const Size(26, 26),
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close, size: 15),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _recordingBar(AppLanguage lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: GlassContainer(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        borderRadius: 22,
        child: Row(
          children: [
            LiquidIconControl(
              child: IconButton(
                tooltip: tr(lang, 'Bekor qilish', 'Отменить', 'Cancel'),
                onPressed: _finishingRecording
                    ? null
                    : () => _finishRecording(send: false),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE5484D),
                ),
              ),
            ),
            const SizedBox(width: 2),
            LiquidSurface(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFFE5484D),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatChatDuration(_recordingDuration.inSeconds),
              style: const TextStyle(
                color: _bubbleText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(lang, 'Ovoz yozilmoqda…', 'Идёт запись…', 'Recording…'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _slate500, fontSize: 13),
              ),
            ),
            _SendButton(
              tooltip: tr(lang, 'Yuborish', 'Отправить', 'Send'),
              onTap: _finishingRecording
                  ? null
                  : () => _finishRecording(send: true),
              child: _finishingRecording
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward,
                      size: 20,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accessible brand-blue send/record action with a 48-point touch target.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.child, this.onTap, this.tooltip});

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: LiquidIconControl(
        child: IconButton.filled(
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.blue,
            disabledBackgroundColor: const Color(0xFFB8D8F6),
            foregroundColor: Colors.white,
          ),
          icon: child,
        ),
      ),
    );
  }
}
