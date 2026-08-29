import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/features/categories/data/category_model.dart';

/// Service categories (see `api/Categories.md`). Reads are public; the CRUD
/// methods require an admin token.
class CategoryService {
  CategoryService({ApiClient? client, this.audience = 'client'})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;
  final String audience;

  /// `GET /categories` — public, ordered by `order` ascending. No pagination.
  Future<List<Category>> getAll() async {
    final data = await _client.get('/categories?audience=$audience');
    return (data as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /category-groups` — localized groups with nested active services.
  Future<List<CategoryGroup>> getGroups() async {
    final data = await _client.get('/category-groups?audience=$audience');
    return (data as List<dynamic>)
        .map((item) => CategoryGroup.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /categories/:id` — public.
  Future<Category> getById(int id) async {
    final data = await _client.get('/categories/$id?audience=$audience');
    return Category.fromJson(data as Map<String, dynamic>);
  }
}
