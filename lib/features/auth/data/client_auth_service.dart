import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/network/auth_tokens.dart';
import 'package:fixleo/features/auth/data/client_model.dart';

/// Result of `verify-otp`: either the user was already registered (tokens +
/// client returned → go to home), or they are new (`isRegistered == false`,
/// no tokens → show the name screen, then call [register]).
class ClientVerifyResult {
  const ClientVerifyResult({
    required this.isRegistered,
    this.tokens,
    this.client,
  });

  final bool isRegistered;
  final AuthTokens? tokens;
  final Client? client;
}

/// Client authentication — phone + SMS OTP, a single login-or-register flow
/// (see `api/LoginOrRegisterClient.md`).
///
/// On a successful login / register this also persists the session via
/// [AuthSession] so subsequent requests are authenticated.
class ClientAuthService {
  ClientAuthService({ApiClient? client, AuthSession? session})
      : _client = client ?? ApiClient.instance,
        _session = session ?? AuthSession.instance;

  final ApiClient _client;
  final AuthSession _session;

  /// `POST /clients/auth/send-otp`. Returns OTP lifetime in seconds.
  Future<int> sendOtp(String phone) async {
    final data = await _client.post('/clients/auth/send-otp', body: {'phone': phone});
    return (data?['expiresInSeconds'] as num?)?.toInt() ?? 300;
  }

  /// `POST /clients/auth/resend-otp` — alias of send-otp (same cooldown).
  Future<int> resendOtp(String phone) async {
    final data = await _client.post('/clients/auth/resend-otp', body: {'phone': phone});
    return (data?['expiresInSeconds'] as num?)?.toInt() ?? 300;
  }

  /// `POST /clients/auth/verify-otp`. Persists the session when the user is
  /// already registered (login). New users must still call [register].
  Future<ClientVerifyResult> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final data = await _client.post(
      '/clients/auth/verify-otp',
      body: {'phone': phone, 'code': code},
    ) as Map<String, dynamic>;

    final isRegistered = data['isRegistered'] == true;
    if (!isRegistered) {
      return const ClientVerifyResult(isRegistered: false);
    }

    final tokens = AuthTokens.fromJson(data);
    await _session.start(
      role: AuthRole.client,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return ClientVerifyResult(
      isRegistered: true,
      tokens: tokens,
      client: Client.fromJson(data['client'] as Map<String, dynamic>),
    );
  }

  /// `POST /clients/auth/register` — completes sign-up for new users. Persists
  /// the session.
  Future<Client> register({
    required String phone,
    required String code,
    required String name,
  }) async {
    final data = await _client.post(
      '/clients/auth/register',
      body: {'phone': phone, 'code': code, 'name': name},
    ) as Map<String, dynamic>;

    final tokens = AuthTokens.fromJson(data);
    await _session.start(
      role: AuthRole.client,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return Client.fromJson(data['client'] as Map<String, dynamic>);
  }

  /// `GET /clients/me` (Bearer token).
  Future<Client> me() async {
    final data = await _client.get('/clients/me');
    return Client.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /clients/me` — the user can only change their own name.
  Future<Client> updateName(String name) async {
    final data = await _client.patch('/clients/me', body: {'name': name});
    return Client.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /clients/auth/logout` — revokes the refresh token, then clears the
  /// local session. Idempotent.
  Future<void> logout() async {
    final refresh = _session.refreshToken;
    if (refresh != null) {
      try {
        await _client.post('/clients/auth/logout', body: {'refreshToken': refresh});
      } on Object {
        // Logout is best-effort; clear locally regardless.
      }
    }
    await _session.clear();
  }

  /// `DELETE /clients/me` — soft-deletes the account, then clears the session.
  Future<void> deleteAccount() async {
    await _client.delete('/clients/me');
    await _session.clear();
  }
}
