import 'package:flutter/material.dart';

import 'package:fixleo/features/request/presentation/chats_list_screen.dart';

/// Master's conversations under the "Chatlar" tab — live data via the shared
/// [LiveChatsScreen] (GET /masters/me/conversations). Tapping a row opens the
/// real order chat.
class MasterChatsScreen extends StatelessWidget {
  const MasterChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LiveChatsScreen(kind: 'master', showBack: false);
  }
}
