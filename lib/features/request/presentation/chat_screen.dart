import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:fixleo/app/app.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/core/realtime/chat_socket.dart';
import 'package:fixleo/features/calls/presentation/call_screen.dart';
import 'package:fixleo/features/request/data/chat_service.dart' as api_chat;
import 'package:fixleo/features/request/presentation/attach_photos_sheet.dart';
import 'package:fixleo/features/request/presentation/client_info_screen.dart';
import 'package:fixleo/features/request/presentation/master_profile_screen.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_media_message.dart';
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
    );
  }
}

enum _ImageUploadStatus { uploading, failed }

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

class _ChatScreenState extends State<ChatScreen> {
  static const _bubbleText = Color(0xFF23232E);
  static const _incomingTime = Color(0xFF9494A3);
  static const _outgoingTime = Color(0xFFEBE8FA);
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

  final List<ChatMessage> _messages = [];
  final List<_ImageUpload> _imageUploads = [];
  bool _loading = true;
  bool _sending = false;
  bool _hasText = false;
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
    _peerName = widget.peerName;
    _peerAvatarUrl = widget.peerAvatarUrl;
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
    _chatSocket.connect((m) {
      if (!mounted || m.sender == widget.kind) return;
      setState(() => _messages.add(_toBubble(m)));
      _scrollToBottom();
      unawaited(_service.markRead(widget.conversationId).catchError((_) {}));
    }, onRead: _markOutgoingMessagesRead);
    // Voice-call signalling: ensure connected (home already connects it app-wide);
    // incoming calls present the call UI globally via showIncomingCallUi.
    CallService.instance.connect(widget.kind, onIncoming: showIncomingCallUi);
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
    final call = CallService.instance;
    await call.startCall(widget.conversationId, displayName: _peerName);
    if (mounted && call.isBusy) _openCallScreen();
  }

  /// Tapping the header now opens the peer's full profile — a browsable
  /// master profile (rating, bio, reviews, work photos) for clients, or a
  /// lighter client-info screen for masters (clients don't have that kind of
  /// public profile) — instead of just a zoomable photo.
  void _openPeerProfile() {
    if (widget.kind == 'client') {
      if (_peerId == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MasterProfileScreen(masterId: _peerId!),
        ),
      );
    } else {
      Navigator.of(context).push(
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
    try {
      final msgs = await _service.messages(widget.conversationId, limit: 50);
      unawaited(_service.markRead(widget.conversationId).catchError((_) {}));
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs.map(_toBubble));
        _loading = false;
      });
      _scrollToBottom();
    } on ApiException {
      if (mounted) setState(() => _loading = false);
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
      durationSec: m.voiceDurationSec,
    );
  }

  void _markOutgoingMessagesRead(int? upToMessageId) {
    if (!mounted) return;
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
        _messages.add(_toBubble(sent));
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
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

  Future<void> _pickAndSendImages() async {
    if (_sending || _recording) return;
    final source = await showAttachPhotosSheet(context);
    if (source == null || !mounted) return;

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
        _messages.add(_toBubble(sent));
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
      final hasPermission = await _recorder.hasPermission().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
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
        _messages.add(_toBubble(sent));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      // Not wrapped in BrandedScaffold — this custom Scaffold needs the
      // ambient glass wash added directly so bubbles have depth to blur.
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
                        child: Text(
                          tr(
                            lang,
                            'Xabarlar yoʻq',
                            'Сообщений нет',
                            'No messages',
                          ),
                          style: const TextStyle(color: _slate500),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: _messages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _bubble(_messages[index]),
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

  /// Top header: identity, live online/offline state and persistent last seen.
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

  /// One message bubble, aligned left (incoming) or right (mine).
  Widget _bubble(ChatMessage m) {
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      // Bubbles repeat dozens of times per scrolling thread — use the
      // blur-less glass variant so long conversations don't jank.
      child: GlassContainer.lite(
        padding: m.type == 'image'
            ? const EdgeInsets.fromLTRB(3, 3, 3, 6)
            : const EdgeInsets.fromLTRB(14, 10, 14, 8),
        borderRadius: 16,
        tint: m.isMine ? AppColors.blue : Colors.white,
        tintOpacityTop: m.isMine ? 0.90 : 0.85,
        tintOpacityBottom: m.isMine ? 0.76 : 0.70,
        borderOpacity: m.isMine ? 0.45 : 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _messageBody(m),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.time,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: -0.12,
                      color: m.isMine ? _outgoingTime : _incomingTime,
                    ),
                  ),
                  // Delivery ticks — only on the user's own messages.
                  if (m.isMine) ...[
                    const SizedBox(width: 3),
                    Icon(
                      m.isRead ? Icons.done_all : Icons.done,
                      size: 13,
                      color: m.isRead ? Colors.white : _outgoingTime,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (m.isMine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ChatPeerAvatar(imageUrl: _peerAvatarUrl, size: 30),
        const SizedBox(width: 6),
        Flexible(child: bubble),
      ],
    );
  }

  Widget _messageBody(ChatMessage message) {
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
    return Text(
      message.text,
      style: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        color: message.isMine ? Colors.white : _bubbleText,
      ),
    );
  }

  /// Bottom input bar: camera, working text field and send button — floating
  /// on the page background like the Figma design.
  Widget _inputBar(AppLanguage lang) {
    if (_recording) return _recordingBar(lang);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          GlassIconButton(
            size: 44,
            semanticLabel: tr(
              lang,
              'Rasm yuborish',
              'Отправить фото',
              'Send photo',
            ),
            onTap: _sending || _startingRecording ? null : _pickAndSendImages,
            child: Icon(
              Icons.photo_camera_outlined,
              size: 22,
              color: _slate500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassTextField(
              controller: _controller,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              height: null,
              hintText: tr(lang, 'Xabar…', 'Сообщение…', 'Message…'),
              textStyle: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.16,
                color: _bubbleText,
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
    return Container(
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
                      DecoratedBox(
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
            IconButton(
              tooltip: tr(lang, 'Bekor qilish', 'Отменить', 'Cancel'),
              onPressed: _finishingRecording
                  ? null
                  : () => _finishRecording(send: false),
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE5484D)),
            ),
            const SizedBox(width: 2),
            Container(
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

/// Round brand-blue glass send/record button used in the composer and the
/// recording bar — [GlassIconButton] only offers the neutral white tint, so
/// this mirrors its structure with [GlassContainer.tinted] instead.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.child, this.onTap, this.tooltip});

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final glass = GlassContainer.tinted(
      width: 40,
      height: 40,
      borderRadius: 20,
      shadow: onTap != null,
      alignment: Alignment.center,
      child: child,
    );
    final button = Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(child: glass),
      ),
    );
    return SizedBox(
      width: 40,
      height: 40,
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button),
    );
  }
}
