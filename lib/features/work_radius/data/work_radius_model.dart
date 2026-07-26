/// A selectable service radius (in km) a master can pick for their work zone.
///
/// See `api/WorkRadius.md` — `WorkRadiusResponseDto`.
class WorkRadius {
  const WorkRadius({
    required this.id,
    required this.km,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int km;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WorkRadius.fromJson(Map<String, dynamic> json) => WorkRadius(
    id: (json['id'] as num).toInt(),
    km: (json['km'] as num).toInt(),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
  );
}
