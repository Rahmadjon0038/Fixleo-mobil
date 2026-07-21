import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/chat_service.dart' as api_chat;
import 'package:fixleo/features/request/presentation/attach_photos_sheet.dart';

/// A single chat message bubble. [isMine] is true for the user's own (blue)
/// bubbles. (Kept as a lightweight display model; the wire model lives in
/// [api_chat.ChatMessage].)
class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.time,
    required this.isMine,
  });

  final String text;
  final String time;
  final bool isMine;
}

/// One-on-one order chat — live thread + working input bar (docs/v3/Chat.md).
/// Reused by both the client side (chatting with the master) and the master
/// side; [kind] picks the `/clients` or `/masters` endpoint prefix.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.peerName,
    this.kind = 'client',
  });

  final int conversationId;
  final String? peerName;
  final String kind; // 'client' | 'master'

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _bubbleText = Color(0xFF23232E);
  static const _incomingTime = Color(0xFF9494A3);
  static const _outgoingTime = Color(0xFFEBE8FA);
  static const _slate500 = Color(0xFF64748B);

  late final api_chat.ChatService _service = api_chat.ChatService(kind: widget.kind);
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    final t = m.createdAt;
    final time = t == null
        ? ''
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final text = switch (m.type) {
      'image' => '📷',
      'call' => '📞 ${m.callDurationSec ?? 0}s',
      _ => m.text ?? '',
    };
    return ChatMessage(text: text, time: time, isMine: m.sender == widget.kind);
  }

  @override
  void dispose() {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, lang),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            tr(lang, 'Xabarlar yoʻq', 'Сообщений нет', 'No messages'),
                            style: const TextStyle(color: _slate500),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          itemCount: _messages.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _bubble(_messages[index]),
                        ),
            ),
            _inputBar(lang),
          ],
        ),
      ),
    );
  }

  /// Top header: back button, centered name + "onlayn", call button.
  Widget _header(BuildContext context, AppLanguage lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.peerName ?? tr(lang, 'Suhbat', 'Чат', 'Chat'),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        letterSpacing: -0.18,
                        fontWeight: FontWeight.w700,
                        color: _bubbleText,
                      ),
                    ),
                    Text(
                      tr(lang, 'onlayn', 'онлайн', 'online'),
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        letterSpacing: -0.16,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _GlassCircleButton(
            icon: Icons.phone_outlined,
            onTap: () {
              // TODO: start a call with the master.
            },
          ),
        ],
      ),
    );
  }

  /// One message bubble, aligned left (incoming) or right (mine).
  Widget _bubble(ChatMessage m) {
    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: m.isMine ? AppColors.blue : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: m.isMine ? Colors.white : _bubbleText,
                ),
              ),
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
                      const Icon(
                        Icons.done_all,
                        size: 13,
                        color: _outgoingTime,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom input bar: camera, working text field and send button — floating
  /// on the page background like the Figma design.
  Widget _inputBar(AppLanguage lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => showAttachPhotosSheet(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 22,
                color: _slate500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: _bubbleText,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: tr(lang, 'Xabar…', 'Сообщение…', 'Message…'),
                  hintStyle: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    color: _slate500,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.arrow_upward,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round iOS "liquid glass" style button used in the chat header.
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.30),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 20, color: AppColors.navy),
            ),
          ),
        ),
      ),
    );
  }
}
