import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/chat_service.dart' as api_chat;
import 'package:fixleo/features/request/presentation/chat_screen.dart';

/// Self-loading chats screen — fetches the real conversations for [kind]
/// ('client' | 'master') and renders them with the shared [ChatsList].
class LiveChatsScreen extends StatefulWidget {
  const LiveChatsScreen({super.key, required this.kind, this.showBack = true});

  final String kind;
  final bool showBack;

  @override
  State<LiveChatsScreen> createState() => _LiveChatsScreenState();
}

class _LiveChatsScreenState extends State<LiveChatsScreen> {
  late final api_chat.ChatService _service = api_chat.ChatService(kind: widget.kind);
  List<Conversation> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final convs = await _service.conversations();
      if (!mounted) return;
      setState(() {
        _items = convs.map(_toRow).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// "14:32" for today, "21.07" for older messages (FINAL list style).
  static String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    String two(int v) => v.toString().padLeft(2, '0');
    if (sameDay) return '${two(local.hour)}:${two(local.minute)}';
    return '${two(local.day)}.${two(local.month)}';
  }

  Conversation _toRow(api_chat.Conversation c) {
    final lang = LocaleController.language.value;
    final t = c.lastMessageType;
    final preview = t == 'image'
        ? '📷 ${tr(lang, 'Foto', 'Фото', 'Photo')}'
        : t == 'call'
            ? '📞 ${tr(lang, 'Qoʻngʻiroq', 'Звонок', 'Call')}'
            : (c.lastMessageText ?? c.orderTitle);
    return Conversation(
      name: c.peerName ?? c.orderTitle,
      last: preview,
      time: _fmtTime(c.lastMessageAt),
      unread: c.unreadCount,
      conversationId: c.id,
      kind: widget.kind,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Chatlar', 'Чаты', 'Chats'),
      showBack: widget.showBack,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF8D96A4))))
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        tr(lang, 'Suhbatlar yoʻq', 'Чатов нет', 'No chats yet'),
                        style: const TextStyle(color: Color(0xFF8D96A4)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ChatsList(
                        conversations: _items,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      ),
                    ),
    );
  }
}

/// One conversation in a chats list (Figma node 963:7387).
class Conversation {
  const Conversation({
    required this.name,
    required this.last,
    required this.time,
    this.unread = 0,
    this.conversationId = 0,
    this.kind = 'client',
    this.seed,
  });

  final String name;
  final String last;
  final String time;
  final int unread;

  /// Backend conversation id — used to open the live [ChatScreen].
  final int conversationId;

  /// Which side is viewing ('client' | 'master').
  final String kind;

  /// Legacy: optional pre-seeded thread (no longer used once wired to the API).
  final List<ChatMessage>? seed;
}

/// Conversations list — one white card with divider-separated rows: round
/// avatar, name, last-message preview, time and an unread badge. Tapping a
/// row opens the shared [ChatScreen]. Used by both the master's "Chatlar"
/// tab and the client's chats screen.
class ChatsList extends StatelessWidget {
  const ChatsList({
    super.key,
    required this.conversations,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 100),
  });

  final List<Conversation> conversations;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              for (var i = 0; i < conversations.length; i++) ...[
                if (i != 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 78,
                    color: Color(0xFFF1F5F9),
                  ),
                _ConversationTile(
                  conversation: conversations[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: conversations[i].conversationId,
                        peerName: conversations[i].name,
                        kind: conversations[i].kind,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Client-side chats screen — the shared [ChatsList] under the standard
/// branded header.
class ClientChatsScreen extends StatelessWidget {
  const ClientChatsScreen({super.key, required this.conversations});

  final List<Conversation> conversations;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Chatlar', 'Чаты', 'Chats'),
      showBack: true,
      body: ChatsList(
        conversations: conversations,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      ),
    );
  }
}

/// One row: round avatar, name + preview, time + unread badge.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  static const _gray = Color(0xFF8D96A4);

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 26, color: _gray),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: _gray,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  c.time,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    letterSpacing: -0.12,
                    color: _gray,
                  ),
                ),
                const SizedBox(height: 6),
                if (c.unread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      '${c.unread}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
