import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';

/// A single chat message. [isMine] is true for the user's own (blue) bubbles.
class _Message {
  const _Message({required this.text, required this.time, required this.isMine});

  final String text;
  final String time;
  final bool isMine;
}

/// Chat with the master — message thread plus a working input bar at the
/// bottom. The seed thread is mock data; sent messages are kept in state.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _bubbleText = Color(0xFF23232E);
  static const _incomingTime = Color(0xFF9494A3);
  static const _outgoingTime = Color(0xFFEBE8FA);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate500 = Color(0xFF64748B);

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Seed conversation shown when the chat opens.
  final _messages = <_Message>[
    const _Message(
      text: 'Salom! Yoʻlga chiqdim, 15 daqiqada yetib boraman.',
      time: '14:32',
      isMine: false,
    ),
    const _Message(text: 'Zoʻr, sizni kutaman!', time: '14:33', isMine: true),
    const _Message(
      text: 'Domofon kodini ayting, iltimos.',
      time: '14:35',
      isMine: false,
    ),
    const _Message(
      text: 'Domofon kodi 1234, rahmat!',
      time: '14:36',
      isMine: false,
    ),
    const _Message(
      text: 'Tushundim, tez orada yetaman.',
      time: '14:37',
      isMine: true,
    ),
    const _Message(
      text: 'Kvartira kalitlarini unutmang!',
      time: '14:38',
      isMine: false,
    ),
    const _Message(text: 'Oldim, hammasi joyida!', time: '14:39', isMine: false),
    const _Message(
      text: 'Yaqinlashyapman, bir daqiqada yetaman!',
      time: '14:41',
      isMine: true,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Current time as "HH:mm" for newly sent messages.
  String _now() {
    final t = TimeOfDay.now();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_Message(text: text, time: _now(), isMine: true));
      _controller.clear();
    });

    // Scroll to the newest message after it has been laid out.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: _messages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _bubble(_messages[index]),
              ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  /// Top header: back button, centered name + "onlayn", call button.
  Widget _header(BuildContext context) {
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
                  children: const [
                    Text(
                      'Aleksey Ivanov',
                      style: TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        letterSpacing: -0.18,
                        fontWeight: FontWeight.w700,
                        color: _bubbleText,
                      ),
                    ),
                    Text(
                      'onlayn',
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
  Widget _bubble(_Message m) {
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
                child: Text(
                  m.time,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    letterSpacing: -0.12,
                    color: m.isMine ? _outgoingTime : _incomingTime,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom input bar: camera, working text field and send button.
  Widget _inputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _slate200,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 22,
              color: _slate500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _slate200,
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
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Xabar…',
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
