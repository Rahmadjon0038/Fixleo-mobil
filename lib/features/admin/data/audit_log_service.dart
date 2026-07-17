import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/paginated.dart';
import 'package:fixleo/features/admin/data/audit_log_model.dart';

/// Read-only access to the admin audit log (see `api/AdminAuditLog.md`).
///
/// Requires an admin token (see [AuthSession]).
class AuditLogService {
  AuditLogService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /admin/audit-logs` — paginated, newest first.
  Future<Paginated<AuditLogEntry>> list({int page = 1, int limit = 20}) async {
    final data = await _client.get('/admin/audit-logs', query: {
      'page': page,
      'limit': limit,
    });
    return Paginated.fromJson(
      data as Map<String, dynamic>,
      AuditLogEntry.fromJson,
    );
  }
}
