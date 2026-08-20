import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/full_screen_image_viewer.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_presence_text.dart';

/// Full-detail view of the client on the other end of a chat — opened by
/// tapping their name/photo in the chat header. Clients don't have a
/// browsable marketplace profile the way masters do, so this shows what the
/// master's own conversation already knows about them (name, photo, phone
/// once revealed, presence) rather than a separate fetch.
class ClientInfoScreen extends StatelessWidget {
  const ClientInfoScreen({
    super.key,
    required this.name,
    this.avatarUrl,
    this.phone,
    this.online,
    this.lastSeenAt,
  });

  final String name;
  final String? avatarUrl;
  final String? phone;
  final bool? online;
  final DateTime? lastSeenAt;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Mijoz', 'Клиент', 'Client'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              radius: 30,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: avatarUrl == null
                        ? null
                        : () => showFullScreenImage(
                            context,
                            avatarUrl!,
                            title: name,
                          ),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatarUrl != null
                          ? Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person,
                                size: 48,
                                color: Color(0xFF8D96A4),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 48,
                              color: Color(0xFF8D96A4),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    online == true
                        ? tr(lang, 'onlayn', 'в сети', 'online')
                        : formatLastSeenLabel(lang, lastSeenAt),
                    style: TextStyle(
                      fontSize: 14,
                      color: online == true
                          ? AppColors.blue
                          : const Color(0xFF8D96A4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _InfoRow(
                icon: Icons.phone_outlined,
                label: tr(lang, 'Telefon', 'Телефон', 'Phone'),
                value: phone?.isNotEmpty == true
                    ? phone!
                    : tr(
                        lang,
                        'Ish boshlanganda koʻrinadi',
                        'Появится, когда начнётся работа',
                        'Shown once the job starts',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8D96A4),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
