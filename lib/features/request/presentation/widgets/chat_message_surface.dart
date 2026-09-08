import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass_platform.dart';

/// Flat, inexpensive surfaces keep long conversations smooth on Android.
class ChatMessageSurface extends StatelessWidget {
  const ChatMessageSurface({
    super.key,
    required this.isMine,
    required this.isRead,
    required this.time,
    required this.child,
    this.isMedia = false,
    this.grouped = false,
  });

  final bool isMine;
  final bool isRead;
  final String time;
  final Widget child;
  final bool isMedia;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final glass = usesGlassMaterial(context);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width * .82).clamp(0, 380),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glass ? null : (isMine ? AppColors.blue : Colors.white),
            gradient: glass
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isMine
                        ? [const Color(0xFF249BFA), AppColors.blue]
                        : [
                            Colors.white.withValues(alpha: .92),
                            Colors.white.withValues(alpha: .76),
                          ],
                  )
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(!isMine && !grouped ? 5 : 18),
              bottomRight: Radius.circular(isMine && !grouped ? 5 : 18),
            ),
            border: isMine ? null : Border.all(color: const Color(0xFFE5EAF0)),
          ),
          child: Padding(
            padding: isMedia
                ? const EdgeInsets.all(5)
                : const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                child,
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMine
                            ? Colors.white70
                            : const Color(0xFF738297),
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Semantics(
                        container: true,
                        label: isRead
                            ? tr(lang, 'O‘qilgan', 'Прочитано', 'Read')
                            : tr(lang, 'Yuborilgan', 'Отправлено', 'Sent'),
                        child: Icon(
                          isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 15,
                          color: isRead ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String chatDateLabel(DateTime date, AppLanguage lang, {DateTime? now}) {
  final local = date.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final day = DateUtils.dateOnly(local);
  if (day == DateUtils.dateOnly(today)) {
    return tr(lang, 'Bugun', 'Сегодня', 'Today');
  }
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return tr(lang, 'Kecha', 'Вчера', 'Yesterday');
  }
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year}';
}

class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE5ECF3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            chatDateLabel(date, LocaleController.language.value),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF607086),
            ),
          ),
        ),
      ),
    ),
  );
}
