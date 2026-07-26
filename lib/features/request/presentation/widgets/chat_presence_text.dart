import 'package:fixleo/app/locale/app_locale.dart';

String _two(int value) => value.toString().padLeft(2, '0');

/// Localized, compact last-seen timestamp used consistently in chat headers
/// and conversation lists.
String formatLastSeenMoment(
  AppLanguage lang,
  DateTime? value, {
  DateTime? now,
}) {
  if (value == null) return '—';
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final date = DateTime(local.year, local.month, local.day);
  final today = DateTime(current.year, current.month, current.day);
  final time = '${_two(local.hour)}:${_two(local.minute)}';

  if (date == today) {
    return '${tr(lang, 'bugun', 'сегодня', 'today')} $time';
  }
  if (date == today.subtract(const Duration(days: 1))) {
    return '${tr(lang, 'kecha', 'вчера', 'yesterday')} $time';
  }
  return '${_two(local.day)}.${_two(local.month)}.${local.year} $time';
}

String formatLastSeenLabel(AppLanguage lang, DateTime? value, {DateTime? now}) {
  return '${tr(lang, 'Oxirgi faollik', 'Был(а)', 'Last seen')}: '
      '${formatLastSeenMoment(lang, value, now: now)}';
}

String formatPresenceSummary(
  AppLanguage lang,
  bool online,
  DateTime? lastSeenAt, {
  DateTime? now,
}) {
  final status = online
      ? tr(lang, 'onlayn', 'в сети', 'online')
      : tr(lang, 'oflayn', 'не в сети', 'offline');
  return '$status · ${formatLastSeenLabel(lang, lastSeenAt, now: now)}';
}
