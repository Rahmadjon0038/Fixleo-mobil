import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/features/categories/data/category_model.dart';

/// Service categories (see `api/Categories.md`). Reads are public; the CRUD
/// methods require an admin token.
class CategoryService {
  CategoryService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /categories` — public, ordered by `order` ascending. No pagination.
  Future<List<Category>> getAll() async {
    final data = await _client.get('/categories');
    return (data as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /categories/:id` — public.
  Future<Category> getById(int id) async {
    final data = await _client.get('/categories/$id');
    return Category.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /admin/categories` — admin. `name` must be unique.
  Future<Category> create({required String name, int? order}) async {
    final data = await _client.post('/admin/categories', body: {
      'name': name,
      'order': ?order,
    });
    return Category.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /admin/categories/:id` — admin, partial update.
  Future<Category> update(int id, {String? name, int? order}) async {
    final data = await _client.patch('/admin/categories/$id', body: {
      'name': ?name,
      'order': ?order,
    });
    return Category.fromJson(data as Map<String, dynamic>);
  }

  /// `DELETE /admin/categories/:id` — admin.
  Future<void> delete(int id) => _client.delete('/admin/categories/$id');
}
