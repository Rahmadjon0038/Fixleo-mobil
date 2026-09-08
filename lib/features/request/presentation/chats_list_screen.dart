import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/features/request/data/chat_service.dart' as api_chat;
import 'package:fixleo/features/request/presentation/chat_screen.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_peer_avatar.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_presence_text.dart';

/// Self-loading chats screen — fetches the real conversations for [kind]
/// ('client' | 'master') and renders them with the shared [ChatsList].
class LiveChatsScreen extends StatefulWidget {
  const LiveChatsScreen({
    super.key,
    required this.kind,
    this.showBack = true,
    this.showTitle = true,
    this.service,
    this.onUnreadChanged,
  });

  final String kind;
  final bool showBack;
  final bool showTitle;
  final api_chat.ChatService? service;
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<LiveChatsScreen> createState() => _LiveChatsScreenState();
}

class _LiveChatsScreenState extends State<LiveChatsScreen> {
  late final api_chat.ChatService _service =
      widget.service ?? api_chat.ChatService(kind: widget.kind);
  List<Conversation> _items = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  StreamSubscription<PresenceUpdate>? _presenceSubscription;
  StreamSubscription<int>? _conversationSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _presenceSubscription = AppPresenceService.instance.updates.listen((
      update,
    ) {
      if (!mounted) return;
      final index = _items.indexWhere(
        (item) => item.conversationId == update.conversationId,
      );
      if (index < 0) return;
      final lang = LocaleController.language.value;
      setState(() {
        final next = [..._items];
        next[index] = next[index].copyWith(
          online: update.online,
          presence: formatPresenceSummary(
            lang,
            update.online,
            update.lastSeenAt,
          ),
        );
        _items = next;
      });
    });
    _conversationSubscription = AppPresenceService.instance.conversationUpdates
        .listen((_) => unawaited(_load(showLoading: false)));
  }

  @override
  void dispose() {
    unawaited(_presenceSubscription?.cancel());
    unawaited(_conversationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final convs = await _service.conversations();
      if (!mounted) return;
      setState(() {
        _items = convs.map(_toRow).toList();
        _loading = false;
        _error = null;
      });
      widget.onUnreadChanged?.call(
        convs.fold(0, (total, item) => total + item.unreadCount),
      );
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
    final sameDay =
        local.year == now.year &&
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
        : t == 'voice'
        ? '🎤 ${tr(lang, 'Ovozli xabar', 'Голосовое сообщение', 'Voice message')}'
        : t == 'location'
        ? '📍 ${tr(lang, 'Joylashuv', 'Местоположение', 'Location')}'
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
      avatarUrl: c.peerAvatarUrl,
      online: c.peerOnline,
      presence: formatPresenceSummary(lang, c.peerOnline, c.peerLastSeenAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final query = _query.trim().toLowerCase();
    final visible = _items
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.last.toLowerCase().contains(query),
        )
        .toList();
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: _error != null || visible.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 64),
                      Icon(
                        _error != null
                            ? Icons.cloud_off_rounded
                            : Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: AppColors.blue,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error ??
                              (query.isNotEmpty
                                  ? tr(
                                      lang,
                                      'Suhbat topilmadi',
                                      'Чат не найден',
                                      'No conversations found',
                                    )
                                  : tr(
                                      lang,
                                      'Suhbatlar shu yerda boshlanadi',
                                      'Здесь начинаются беседы',
                                      'Your conversations start here',
                                    )),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_error != null)
                        Center(
                          child: TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              tr(
                                lang,
                                'Qayta urinish',
                                'Повторить',
                                'Try again',
                              ),
                            ),
                          ),
                        ),
                      if (_error == null && query.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            tr(
                              lang,
                              'Buyurtma bo‘yicha xabarlar va kelishuvlar bir joyda.',
                              'Сообщения и договорённости по заказам в одном месте.',
                              'Messages and arrangements for your orders, all in one place.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ),
                    ],
                  )
                : ChatsList(
                    conversations: visible,
                    onConversationClosed: () => _load(showLoading: false),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      widget.showBack ? 20 : 100,
                    ),
                  ),
          );
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: tr(
                lang,
                'Suhbatni qidirish',
                'Поиск чатов',
                'Search conversations',
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF7C8B9D),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
    if (!widget.showTitle && !widget.showBack) return content;
    return BrandedScaffold(
      title: widget.showTitle ? tr(lang, 'Chatlar', 'Чаты', 'Chats') : null,
      showBack: widget.showBack,
      body: content,
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
    this.avatarUrl,
    this.online = false,
    this.presence,
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

  /// Resolved backend URL of the other participant's profile photo.
  final String? avatarUrl;
  final bool online;
  final String? presence;

  /// Legacy: optional pre-seeded thread (no longer used once wired to the API).
  final List<ChatMessage>? seed;

  Conversation copyWith({bool? online, String? presence}) {
    return Conversation(
      name: name,
      last: last,
      time: time,
      unread: unread,
      conversationId: conversationId,
      kind: kind,
      avatarUrl: avatarUrl,
      online: online ?? this.online,
      presence: presence ?? this.presence,
      seed: seed,
    );
  }
}

/// Conversations list — one white card with divider-separated rows: round
/// avatar, name, last-message preview, time and an unread badge. Tapping a
/// row opens the shared [ChatScreen]. Used by both the master's "Chatlar"
/// tab and the client's chats screen.
class ChatsList extends StatelessWidget {
  const ChatsList({
    super.key,
    required this.conversations,
    this.onConversationClosed,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 100),
  });

  final List<Conversation> conversations;
  final Future<void> Function()? onConversationClosed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: padding,
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ConversationTile(
        conversation: conversations[index],
        onTap: () =>
            unawaited(_openConversation(context, conversations[index])),
      ),
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    Conversation conversation,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.conversationId,
          peerName: conversation.name,
          peerAvatarUrl: conversation.avatarUrl,
          kind: conversation.kind,
        ),
      ),
    );
    await onConversationClosed?.call();
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
    return Material(
      color: c.unread > 0 ? const Color(0xFFF9FCFF) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  ChatPeerAvatar(imageUrl: c.avatarUrl, name: c.name, size: 52),
                  if (c.online)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16B887),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        letterSpacing: -0.18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    if (c.presence != null) ...[
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.online
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              c.presence!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 15 / 11,
                                color: c.online ? AppColors.blue : _gray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                        c.unread > 99 ? '99+' : '${c.unread}',
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
      ),
    );
  }
}
