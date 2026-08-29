import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_config.dart';

/// A service category masters offer and clients pick (see `api/Categories.md`).
class Category {
  const Category({
    required this.id,
    required this.name,
    this.slug = '',
    this.titleUz = '',
    this.titleRu = '',
    this.titleEn = '',
    this.description = '',
    this.descriptionUz = '',
    this.descriptionRu = '',
    this.descriptionEn = '',
    this.tags = const [],
    this.imageUrl,
    this.icon,
    this.requiresTools = false,
    this.order = 0,
    this.isActive = true,
    this.groupId = 0,
    this.groupTitle = '',
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String slug;
  final String titleUz;
  final String titleRu;
  final String titleEn;
  final String description;
  final String descriptionUz;
  final String descriptionRu;
  final String descriptionEn;
  final List<String> tags;
  final String? imageUrl;
  final String? icon;
  final bool requiresTools;
  final int order;
  final bool isActive;
  final int groupId;
  final String groupTitle;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String localizedName(AppLanguage language) => switch (language) {
    AppLanguage.uz => titleUz.isNotEmpty ? titleUz : name,
    AppLanguage.ru => titleRu.isNotEmpty ? titleRu : name,
    AppLanguage.en => titleEn.isNotEmpty ? titleEn : name,
  };

  String localizedDescription(AppLanguage language) => switch (language) {
    AppLanguage.uz => descriptionUz.isNotEmpty ? descriptionUz : description,
    AppLanguage.ru => descriptionRu.isNotEmpty ? descriptionRu : description,
    AppLanguage.en => descriptionEn.isNotEmpty ? descriptionEn : description,
  };

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      name,
      titleUz,
      titleRu,
      titleEn,
      description,
      descriptionUz,
      descriptionRu,
      descriptionEn,
      slug,
      ...tags,
    ].join(' ').toLowerCase().contains(normalized);
  }

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    titleUz: json['titleUz'] as String? ?? '',
    titleRu: json['titleRu'] as String? ?? '',
    titleEn: json['titleEn'] as String? ?? '',
    description: json['description'] as String? ?? '',
    descriptionUz: json['descriptionUz'] as String? ?? '',
    descriptionRu: json['descriptionRu'] as String? ?? '',
    descriptionEn: json['descriptionEn'] as String? ?? '',
    tags: (json['tags'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .toList(growable: false),
    imageUrl: ApiConfig.resolveMediaUrl(json['imageUrl']),
    icon: json['icon'] as String?,
    requiresTools: json['requiresTools'] as bool? ?? false,
    order: (json['order'] as num?)?.toInt() ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    groupId: (json['groupId'] as num?)?.toInt() ?? 0,
    groupTitle: json['groupTitle'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
  );
}

class CategoryGroup {
  const CategoryGroup({
    required this.id,
    required this.slug,
    required this.title,
    required this.titleUz,
    required this.titleRu,
    required this.titleEn,
    this.description = '',
    this.descriptionUz = '',
    this.descriptionRu = '',
    this.descriptionEn = '',
    required this.order,
    required this.isActive,
    this.isActiveUsers = true,
    required this.services,
  });

  final int id;
  final String slug;
  final String title;
  final String titleUz;
  final String titleRu;
  final String titleEn;
  final String description;
  final String descriptionUz;
  final String descriptionRu;
  final String descriptionEn;
  final int order;
  final bool isActive;
  final bool isActiveUsers;
  final List<Category> services;

  String localizedTitle(AppLanguage language) => switch (language) {
    AppLanguage.uz => titleUz,
    AppLanguage.ru => titleRu,
    AppLanguage.en => titleEn,
  };

  String localizedDescription(AppLanguage language) => switch (language) {
    AppLanguage.uz => descriptionUz.isNotEmpty ? descriptionUz : description,
    AppLanguage.ru => descriptionRu.isNotEmpty ? descriptionRu : description,
    AppLanguage.en => descriptionEn.isNotEmpty ? descriptionEn : description,
  };

  factory CategoryGroup.fromJson(Map<String, dynamic> json) => CategoryGroup(
    id: (json['id'] as num).toInt(),
    slug: json['slug'] as String? ?? '',
    title: json['title'] as String? ?? '',
    titleUz: json['titleUz'] as String? ?? '',
    titleRu: json['titleRu'] as String? ?? '',
    titleEn: json['titleEn'] as String? ?? '',
    description: json['description'] as String? ?? '',
    descriptionUz: json['descriptionUz'] as String? ?? '',
    descriptionRu: json['descriptionRu'] as String? ?? '',
    descriptionEn: json['descriptionEn'] as String? ?? '',
    order: (json['order'] as num?)?.toInt() ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    isActiveUsers: json['isActiveUsers'] as bool? ?? true,
    services: (json['services'] as List<dynamic>? ?? const [])
        .map((service) => Category.fromJson(service as Map<String, dynamic>))
        .toList(growable: false),
  );
}
