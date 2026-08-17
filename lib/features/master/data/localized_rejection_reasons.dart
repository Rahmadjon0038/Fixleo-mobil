import 'package:fixleo/app/locale/app_locale.dart';

/// Moderator rejection copy in every language supported by the mobile app.
class LocalizedRejectionReasons {
  const LocalizedRejectionReasons({this.uz, this.ru, this.en, this.legacy});

  final String? uz;
  final String? ru;
  final String? en;
  final String? legacy;

  factory LocalizedRejectionReasons.fromJson(dynamic json, {String? legacy}) {
    final reasons = json is Map ? Map<String, dynamic>.from(json) : null;
    return LocalizedRejectionReasons(
      uz: reasons?['uz'] as String?,
      ru: reasons?['ru'] as String?,
      en: reasons?['en'] as String?,
      legacy: legacy,
    );
  }

  String? forLanguage(AppLanguage language) {
    final localized = switch (language) {
      AppLanguage.uz => uz,
      AppLanguage.ru => ru,
      AppLanguage.en => en,
    };
    return _nonEmpty(localized) ??
        _nonEmpty(legacy) ??
        _nonEmpty(ru) ??
        _nonEmpty(uz) ??
        _nonEmpty(en);
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
