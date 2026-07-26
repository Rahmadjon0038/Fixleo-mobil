import 'package:flutter/foundation.dart';

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/network/api_config.dart';

/// The signed-in user's own profile (name/phone), cached app-wide so screens
/// like the Home greeting show the real account instead of a hardcoded name.
///
/// Loaded lazily from `GET /clients/me` or `GET /masters/me` (whichever role is
/// active) and exposed as a [ValueListenable] so widgets rebuild when it lands.
class CurrentUser {
  CurrentUser._();
  static final CurrentUser instance = CurrentUser._();

  final ValueNotifier<UserProfile?> profile = ValueNotifier<UserProfile?>(null);

  String? get name => profile.value?.name;

  /// Fetches the current user's profile for the active role. Safe to call from
  /// several screens — failures are swallowed (the greeting just falls back).
  Future<void> refresh({ApiClient? client}) async {
    final role = AuthSession.instance.role;
    if (role == null || !AuthSession.instance.isLoggedIn) {
      profile.value = null;
      return;
    }
    final api = client ?? ApiClient.instance;
    final path = switch (role) {
      AuthRole.client => '/clients/me',
      AuthRole.master => '/masters/me',
      AuthRole.admin => '/auth/me',
    };
    try {
      final data = await api.get(path);
      if (data is Map<String, dynamic>) {
        profile.value = UserProfile(
          name: data['name'] as String?,
          phone: data['phone'] as String?,
          city: data['city'] as String?,
          avatarUrl: ApiConfig.resolveMediaUrl(data['avatarUrl']),
        );
      }
    } catch (_) {
      // keep whatever we had; the greeting falls back to a generic label
    }
  }

  void clear() => profile.value = null;
}

class UserProfile {
  const UserProfile({this.name, this.phone, this.city, this.avatarUrl});
  final String? name;
  final String? phone;
  final String? city;
  final String? avatarUrl;

  /// First name only, for the greeting ("Добрый день, Арслан!").
  String? get firstName {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }
}
