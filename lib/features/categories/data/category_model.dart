/// A service category masters offer and clients pick (see `api/Categories.md`).
class Category {
  const Category({
    required this.id,
    required this.name,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    order: (json['order'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
  );
}
