import 'package:fixleo/app/locale/app_locale.dart';

/// Human-readable order timing used consistently in client and master flows.
String orderTimingLabel(
  AppLanguage lang, {
  required String timing,
  String? scheduledDate,
  String? slotLabel,
}) {
  if (timing == 'asap') {
    return tr(lang, 'Shoshilinch — hozir', 'Срочно — сейчас', 'Urgent — now');
  }

  final day = timing == 'today'
      ? tr(lang, 'Bugun', 'Сегодня', 'Today')
      : (scheduledDate?.trim().isNotEmpty == true
            ? scheduledDate!.trim()
            : tr(lang, 'Rejalashtirilgan', 'Запланировано', 'Scheduled'));
  return slotLabel?.trim().isNotEmpty == true
      ? '$day, ${slotLabel!.trim()}'
      : day;
}
