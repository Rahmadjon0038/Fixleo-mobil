import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/paginated.dart';
import 'package:fixleo/features/admin/data/verification_model.dart';
import 'package:fixleo/features/master/data/master_model.dart';

/// Admin management of masters and KYC moderation (see `api/AdminMasters.md`).
/// All routes require an admin token. `:id` paths take the **numeric** DB id.
class AdminMasterService {
  AdminMasterService({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  // ── Masters ─────────────────────────────────────────────────────────────

  /// `GET /admin/masters` — paginated, with optional search / status filters.
  Future<Paginated<Master>> list({
    int page = 1,
    int limit = 20,
    String? search,
    MasterStatus? status,
    VerificationStatus? verificationStatus,
  }) async {
    final data = await _client.get('/admin/masters', query: {
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null) 'status': status.name,
      if (verificationStatus != null)
        'verificationStatus': _verificationApi(verificationStatus),
    });
    return Paginated.fromJson(data as Map<String, dynamic>, Master.fromJson);
  }

  /// `GET /admin/masters/:id`.
  Future<Master> getById(int id) async {
    final data = await _client.get('/admin/masters/$id');
    return Master.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /admin/masters/:id/block` — reason optional.
  Future<Master> block(int id, {String? reason}) async {
    final data = await _client.patch(
      '/admin/masters/$id/block',
      body: {'reason': ?reason},
    );
    return Master.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /admin/masters/:id/unblock`.
  Future<Master> unblock(int id) async {
    final data = await _client.patch('/admin/masters/$id/unblock');
    return Master.fromJson(data as Map<String, dynamic>);
  }

  // ── Verifications (KYC moderation) ───────────────────────────────────────

  /// `GET /admin/verifications` — moderation queue, oldest first.
  Future<Paginated<VerificationListItem>> verifications({
    int page = 1,
    int limit = 20,
    String status = 'pending',
  }) async {
    final data = await _client.get('/admin/verifications', query: {
      'page': page,
      'limit': limit,
      'status': status,
    });
    return Paginated.fromJson(
      data as Map<String, dynamic>,
      VerificationListItem.fromJson,
    );
  }

  /// `GET /admin/verifications/:id`.
  Future<VerificationDetail> verification(int id) async {
    final data = await _client.get('/admin/verifications/$id');
    return VerificationDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /admin/verifications/:id/approve` — checklist optional.
  Future<VerificationDetail> approve(
    int id, {
    bool? documentReadable,
    bool? photoMatchesSelfie,
    bool? dataMatchesForm,
  }) async {
    final data = await _client.post('/admin/verifications/$id/approve', body: {
      'documentReadable': ?documentReadable,
      'photoMatchesSelfie': ?photoMatchesSelfie,
      'dataMatchesForm': ?dataMatchesForm,
    });
    return VerificationDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /admin/verifications/:id/reject` — `reason` required.
  Future<VerificationDetail> reject(
    int id, {
    required String reason,
    bool? documentReadable,
    bool? photoMatchesSelfie,
    bool? dataMatchesForm,
  }) async {
    final data = await _client.post('/admin/verifications/$id/reject', body: {
      'reason': reason,
      'documentReadable': ?documentReadable,
      'photoMatchesSelfie': ?photoMatchesSelfie,
      'dataMatchesForm': ?dataMatchesForm,
    });
    return VerificationDetail.fromJson(data as Map<String, dynamic>);
  }

  String _verificationApi(VerificationStatus s) => switch (s) {
        VerificationStatus.notSubmitted => 'not_submitted',
        VerificationStatus.pending => 'pending',
        VerificationStatus.approved => 'approved',
        VerificationStatus.rejected => 'rejected',
      };
}
