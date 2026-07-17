import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/paginated.dart';
import 'package:fixleo/features/admin/data/admin_client_model.dart';

/// Admin management of client (end-user) accounts (see `api/AdminClients.md`).
///
/// Every route requires an admin token (`admin` or `superadmin`) — set it via
/// [AuthSession] before calling these. Mutation routes take the **numeric**
/// DB id (e.g. `3`), not the public `#U-...` id.
class AdminClientService {
  AdminClientService({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /admin/clients` — paginated list with optional search / status filter.
  Future<Paginated<AdminClient>> list({
    int page = 1,
    int limit = 20,
    String? search,
    ClientStatus? status,
  }) async {
    final data = await _client.get('/admin/clients', query: {
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null) 'status': status.apiValue,
    });
    return Paginated.fromJson(
      data as Map<String, dynamic>,
      AdminClient.fromJson,
    );
  }

  /// `GET /admin/clients/:id`.
  Future<AdminClient> getById(int id) async {
    final data = await _client.get('/admin/clients/$id');
    return AdminClient.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /admin/clients` — only [phone] is required.
  Future<AdminClient> create({
    required String phone,
    String? name,
    ClientStatus? status,
    String? blockReason,
  }) async {
    final data = await _client.post('/admin/clients', body: {
      'phone': phone,
      'name': ?name,
      'status': ?status?.apiValue,
      'blockReason': ?blockReason,
    });
    return AdminClient.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /admin/clients/:id` — partial update; only sent fields change.
  Future<AdminClient> update(
    int id, {
    String? phone,
    String? name,
    ClientStatus? status,
    String? blockReason,
  }) async {
    final data = await _client.patch('/admin/clients/$id', body: {
      'phone': ?phone,
      'name': ?name,
      'status': ?status?.apiValue,
      'blockReason': ?blockReason,
    });
    return AdminClient.fromJson(data as Map<String, dynamic>);
  }

  /// `PUT /admin/clients/:id` — full replace; [phone], [name], [status] required.
  Future<AdminClient> replace(
    int id, {
    required String phone,
    required String name,
    required ClientStatus status,
    String? blockReason,
  }) async {
    final data = await _client.put('/admin/clients/$id', body: {
      'phone': phone,
      'name': name,
      'status': status.apiValue,
      'blockReason': ?blockReason,
    });
    return AdminClient.fromJson(data as Map<String, dynamic>);
  }

  /// `DELETE /admin/clients/:id` — soft delete (frees the phone number).
  Future<void> delete(int id) => _client.delete('/admin/clients/$id');

  /// `PATCH /admin/clients/:id/block` — [reason] is optional.
  Future<AdminClient> block(int id, {String? reason}) async {
    final data = await _client.patch(
      '/admin/clients/$id/block',
      body: {'reason': ?reason},
    );
    return AdminClient.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /admin/clients/:id/unblock`.
  Future<AdminClient> unblock(int id) async {
    final data = await _client.patch('/admin/clients/$id/unblock');
    return AdminClient.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /admin/clients/:id/reset-otp` — clears the pending OTP.
  Future<AdminClient> resetOtp(int id) async {
    final data = await _client.patch('/admin/clients/$id/reset-otp');
    return AdminClient.fromJson(data as Map<String, dynamic>);
  }
}
