import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/features/request/presentation/chat_screen.dart';

/// One conversation row in the master's "Chatlar" list.
class _Conversation {
  const _Conversation({
    required this.name,
    required this.last,
    required this.time,
    this.unread = 0,
    this.seed,
  });

  final String name;
  final String last;
  final String time;
  final int unread;

  /// Optional pre-seeded thread opened when this row is tapped.
  final List<ChatMessage>? seed;
}

/// Master's conversations list — shown under the "Chatlar" tab. Tapping a row
/// opens the shared [ChatScreen] for that client.
class MasterChatsScreen extends StatelessWidget {
  const MasterChatsScreen({super.key});

  // The thread for the active client (matches the current job).
  static const _arslanThread = <ChatMessage>[
    ChatMessage(
      text: 'Assalomu alaykum! Yoʻlga chiqdim, 15 daqiqada yetib boraman.',
      time: '14:33',
      isMine: true,
    ),
    ChatMessage(text: 'Rahmat, kutaman!', time: '14:35', isMine: false),
    ChatMessage(text: 'Domofon kodi 1234', time: '14:36', isMine: false),
    ChatMessage(
      text: 'Tushunarli, tez yetib boraman.',
      time: '14:37',
      isMine: true,
    ),
    ChatMessage(text: 'Yaqin qoldingizmi?', time: '14:39', isMine: false),
    ChatMessage(
      text: 'Yaqinlashyapman, bir daqiqada!',
      time: '14:41',
      isMine: true,
    ),
  ];

  static const _conversations = <_Conversation>[
    _Conversation(
      name: 'Arslan Koptleulov',
      last: 'Yaqinlashyapman, bir daqiqada!',
      time: '14:41',
      seed: _arslanThread,
    ),
    _Conversation(
      name: 'Dilshod Karimov',
      last: 'Rahmat, ishingizdan mamnunman!',
      time: 'Kecha',
    ),
    _Conversation(
      name: 'Nigora Aliyeva',
      last: 'Qachon kela olasiz?',
      time: 'Dush',
      unread: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        for (final c in _conversations) ...[
          _ConversationTile(
            conversation: c,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(peerName: c.name, seed: c.seed),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// White rounded card: avatar, name + last-message preview, time + unread.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final _Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person,
                size: 26,
                color: Color(0xFF8D96A4),
              ),
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
                  Text(
                    c.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: Color(0xFF8D96A4),
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
                    color: Color(0xFF9494A3),
                  ),
                ),
                const SizedBox(height: 6),
                if (c.unread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(10),
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
