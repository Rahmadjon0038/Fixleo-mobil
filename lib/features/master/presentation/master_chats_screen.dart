import 'package:flutter/material.dart';

import 'package:fixleo/features/request/presentation/chat_screen.dart';
import 'package:fixleo/features/request/presentation/chats_list_screen.dart';

/// Master's conversations list — shown under the "Chatlar" tab. Renders the
/// shared [ChatsList]; tapping a row opens the shared [ChatScreen] for that
/// client. Mock data for now.
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

  static const _conversations = <Conversation>[
    Conversation(
      name: 'Arslan Koptleulov',
      last: 'Yaqinlashyapman, bir daqiqada!',
      time: '14:41',
      unread: 2,
      seed: _arslanThread,
    ),
    Conversation(
      name: 'Dilshod Karimov',
      last: 'Rahmat, ishingizdan mamnunman!',
      time: 'Kecha',
      unread: 1,
    ),
    Conversation(
      name: 'Nigora Aliyeva',
      last: 'Qachon kela olasiz?',
      time: 'Dush',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const ChatsList(conversations: _conversations);
  }
}
