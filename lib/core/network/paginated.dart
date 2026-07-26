/// Pagination metadata returned by list endpoints under `data.meta`:
///
/// ```json
/// { "total": 42, "page": 1, "limit": 10, "totalPages": 5 }
/// ```
class PageMeta {
  const PageMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int limit;
  final int totalPages;

  /// Whether another page can be requested after [page].
  bool get hasMore => page < totalPages;

  factory PageMeta.fromJson(Map<String, dynamic> json) => PageMeta(
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    limit: (json['limit'] as num?)?.toInt() ?? 0,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
  );
}

/// A page of [items] plus its [meta], mirroring the backend's paginated
/// `data: { items: [...], meta: {...} }` shape.
class Paginated<T> {
  const Paginated({required this.items, required this.meta});

  final List<T> items;
  final PageMeta meta;

  /// Parses a `data` map into a typed page, mapping each raw item with [fromJson].
  factory Paginated.fromJson(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawItems = (data['items'] as List<dynamic>? ?? const []);
    return Paginated<T>(
      items: rawItems
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      meta: PageMeta.fromJson(
        (data['meta'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}
