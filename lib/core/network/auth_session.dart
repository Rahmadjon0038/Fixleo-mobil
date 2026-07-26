import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Increments only when a persisted login becomes unusable (expired/revoked
  /// refresh token). The app listens to this and returns to the login flow.
  /// Explicit logout uses [clear] and keeps its existing screen transition.
  final ValueNotifier<int> expirationEvents = ValueNotifier<int>(0);

  /// Increments whenever the active account starts or ends. App-wide services
  /// (presence, call signalling, etc.) can follow login/logout without being
  /// tied to a particular screen.
  final ValueNotifier<int> sessionEvents = ValueNotifier<int>(0);

  AuthRole? get role => _role;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;
  bool get hasToken => isLoggedIn;
  bool get canRefresh =>
      _role != null && _refreshToken != null && _refreshToken!.isNotEmpty;

  Map<String, dynamic>? get _accessTokenPayload {
    final token = _accessToken;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      return jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          )
          as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  /// Numeric backend account id (`sub`) carried by the active access token.
  ///
  /// This is not trusted for authorization; it only lets app-wide services tie
  /// durable local work (for example a pending call recording) to the account
  /// that created it, so another login can never upload the wrong user's file.
  int? get subjectId {
    final sub = _accessTokenPayload?['sub'];
    if (sub is num) return sub.toInt();
    return int.tryParse(sub?.toString() ?? '');
  }

  /// JWT access-token expiry, read locally without trusting it for
  /// authorization. This is used only to refresh shortly before expiry rather
  /// than first sending a request that is guaranteed to receive a 401.
  DateTime? get accessTokenExpiresAt {
    final exp = (_accessTokenPayload?['exp'] as num?)?.toInt();
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }

  bool accessTokenExpiresWithin(Duration duration) {
    final expiresAt = accessTokenExpiresAt;
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(DateTime.now().toUtc().add(duration));
  }

  /// Loads any persisted session at app startup. Call once from `main()`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _role = AuthRole.fromName(prefs.getString(_kRole));
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);

    // A partially-written/corrupted session cannot be refreshed safely.
    if (_role == null ||
        _accessToken == null ||
        _accessToken!.isEmpty ||
        _refreshToken == null ||
        _refreshToken!.isEmpty) {
      await clear();
    }
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
    sessionEvents.value++;
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
    final hadSession =
        _role != null || _accessToken != null || _refreshToken != null;
    _role = null;
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    if (hadSession) {
      sessionEvents.value++;
    }
  }

  /// Clears an unusable login and notifies the root navigator exactly once.
  Future<void> expire() async {
    final hadSession =
        _role != null || _accessToken != null || _refreshToken != null;
    await clear();
    if (hadSession) {
      expirationEvents.value++;
    }
  }
}
