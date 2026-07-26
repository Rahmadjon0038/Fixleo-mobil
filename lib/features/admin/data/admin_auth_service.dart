import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/network/auth_tokens.dart';
import 'package:fixleo/features/admin/data/admin_model.dart';

/// Admin authentication — email + password (see `api/AdminLogin.md`).
/// Persists the session as [AuthRole.admin].
class AdminAuthService {
  AdminAuthService({ApiClient? client, AuthSession? session})
    : _client = client ?? ApiClient.instance,
      _session = session ?? AuthSession.instance;

  final ApiClient _client;
  final AuthSession _session;

  /// `POST /auth/login`. On success persists the admin session and returns the
  /// admin profile.
  Future<Admin> login({required String email, required String password}) async {
    final data =
        await _client.post(
              '/auth/login',
              body: {'email': email, 'password': password},
            )
            as Map<String, dynamic>;

    final tokens = AuthTokens.fromJson(data);
    await _session.start(
      role: AuthRole.admin,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return Admin.fromJson(data['admin'] as Map<String, dynamic>);
  }

  /// `GET /auth/me`.
  Future<Admin> me() async {
    final data = await _client.get('/auth/me');
    return Admin.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /auth/logout` — revokes the refresh token, clears session.
  Future<void> logout() async {
    final refresh = _session.refreshToken;
    if (refresh != null) {
      try {
        await _client.post('/auth/logout', body: {'refreshToken': refresh});
      } on Object {
        // best-effort
      }
    }
    await _session.clear();
  }
}
