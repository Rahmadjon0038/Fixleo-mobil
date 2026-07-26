/// An access + refresh token pair, as returned by every auth endpoint
/// (`verify-otp`, `register`, `refresh`, admin `login`).
///
/// `accessToken` lives ~15 min and is sent on every request; `refreshToken`
/// lives longer (7 days) and exchanges for a new pair. See
/// `api/Backend Config for client.md`.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );
}
