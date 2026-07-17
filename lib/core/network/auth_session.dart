import 'package:shared_preferences/shared_preferences.dart';

/// Which kind of account the stored tokens belong to. Each has its own auth
/// endpoints and its token does not work on the others (see
/// `api/Backend Config for client.md`).
enum AuthRole {
  client,
  master,
  admin;

  static AuthRole? fromName(String? value) {
    for (final r in AuthRole.values) {
      if (r.name == value) return r;
    }
    return null;
  }
}

/// The active login session — the current access / refresh token pair and the
/// role they belong to. Persisted to disk so the user stays logged in across
/// app restarts.
///
/// This app serves both **client** and **master** users (chosen on the welcome
/// screen); only one is logged in at a time, so a single active session is
/// enough. [ApiClient] reads [accessToken] for every request and uses [role]
/// to pick the right `/refresh` endpoint when an access token expires.
class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  static const _kRole = 'auth_role';
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';

  AuthRole? _role;
  String? _accessToken;
  String? _refreshToken;

  AuthRole? get role => _role;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;
  bool get hasToken => isLoggedIn;

  /// Loads any persisted session at app startup. Call once from `main()`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _role = AuthRole.fromName(prefs.getString(_kRole));
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
  }

  /// Starts a new session after a successful login / register and persists it.
  Future<void> start({
    required AuthRole role,
    required String accessToken,
    required String refreshToken,
  }) async {
    _role = role;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role.name);
    await prefs.setString(_kAccess, accessToken);
    await prefs.setString(_kRefresh, refreshToken);
  }

  /// Replaces the token pair after a refresh, keeping the same role.
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, accessToken);
    await prefs.setString(_kRefresh, refreshToken);
  }

  /// Clears the session (logout / account deleted / refresh failed).
  Future<void> clear() async {
    _role = null;
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }
}
