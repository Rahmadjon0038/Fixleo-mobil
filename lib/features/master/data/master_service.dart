import 'package:dio/dio.dart';

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/network/auth_tokens.dart';
import 'package:fixleo/features/master/data/master_document_model.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/app/locale/app_locale.dart';

/// Result of master `verify-otp`: tokens + profile, plus whether this call
/// just created the master (`isNewMaster == true` → start onboarding from the
/// beginning; otherwise resume by `master.verificationStatus`).
class MasterVerifyResult {
  const MasterVerifyResult({
    required this.isNewMaster,
    required this.tokens,
    required this.master,
  });

  final bool isNewMaster;
  final AuthTokens tokens;
  final Master master;
}

/// Master authentication, onboarding and KYC (see `api/MasterRegister.md`).
///
/// Auth uses phone + SMS OTP; `verify-otp` issues tokens immediately so the
/// multi-step onboarding runs authenticated. Persists the session via
/// [AuthSession].
class MasterService {
  MasterService({ApiClient? client, AuthSession? session})
    : _client = client ?? ApiClient.instance,
      _session = session ?? AuthSession.instance;

  final ApiClient _client;
  final AuthSession _session;

  // ── Auth ──────────────────────────────────────────────────────────────

  /// `POST /masters/auth/send-otp`. Returns OTP lifetime in seconds.
  Future<int> sendOtp(String phone) async {
    final data = await _client.post(
      '/masters/auth/send-otp',
      body: {'phone': phone, 'language': LocaleController.language.value.name},
    );
    return (data?['expiresInSeconds'] as num?)?.toInt() ?? 300;
  }

  /// `POST /masters/auth/resend-otp` — alias of send-otp (same cooldown).
  Future<int> resendOtp(String phone) async {
    final data = await _client.post(
      '/masters/auth/resend-otp',
      body: {'phone': phone, 'language': LocaleController.language.value.name},
    );
    return (data?['expiresInSeconds'] as num?)?.toInt() ?? 300;
  }

  /// `POST /masters/auth/verify-otp` — login or first-time create. Persists
  /// the session.
  Future<MasterVerifyResult> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final data =
        await _client.post(
              '/masters/auth/verify-otp',
              body: {'phone': phone, 'code': code},
            )
            as Map<String, dynamic>;

    final tokens = AuthTokens.fromJson(data);
    await _session.start(
      role: AuthRole.master,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return MasterVerifyResult(
      isNewMaster: data['isNewMaster'] == true,
      tokens: tokens,
      master: Master.fromJson(data['master'] as Map<String, dynamic>),
    );
  }

  /// `POST /masters/auth/logout` — revokes the refresh token, clears session.
  Future<void> logout() async {
    final refresh = _session.refreshToken;
    if (refresh != null) {
      try {
        await _client.post(
          '/masters/auth/logout',
          body: {'refreshToken': refresh},
        );
      } on Object {
        // best-effort
      }
    }
    await _session.clear();
  }

  // ── Profile / onboarding ────────────────────────────────────────────────

  /// `GET /masters/me`.
  Future<Master> me() async {
    final data = await _client.get('/masters/me');
    return Master.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /masters/me/profile` — name / city / experience (partial).
  Future<Master> updateProfile({
    String? name,
    String? city,
    int? experienceYears,
  }) async {
    final data = await _client.patch(
      '/masters/me/profile',
      body: {'name': ?name, 'city': ?city, 'experienceYears': ?experienceYears},
    );
    return Master.fromJson(data as Map<String, dynamic>);
  }

  /// `PATCH /masters/me/about` — bio.
  Future<Master> updateAbout(String bio) async {
    final data = await _client.patch('/masters/me/about', body: {'bio': bio});
    return Master.fromJson(data as Map<String, dynamic>);
  }

  /// Profile photo is mandatory for masters. Re-uploading replaces the old one.
  Future<Master> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.postMultipart('/masters/me/avatar', formData);
    return Master.fromJson(data as Map<String, dynamic>);
  }

  /// `PUT /masters/me/categories` — replaces the whole selection.
  Future<Master> setCategories(List<int> categoryIds) async {
    final data = await _client.put(
      '/masters/me/categories',
      body: {'categoryIds': categoryIds},
    );
    return Master.fromJson(data as Map<String, dynamic>);
  }

  /// `PUT /masters/me/work-zone` — base location + service radius. `workRadiusKm`
  /// must be one of the allowed values (see `WorkRadiusService`).
  Future<Master> setWorkZone({
    required double latitude,
    required double longitude,
    required int workRadiusKm,
  }) async {
    final data = await _client.put(
      '/masters/me/work-zone',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'workRadiusKm': workRadiusKm,
      },
    );
    return Master.fromJson(data as Map<String, dynamic>);
  }

  // ── KYC documents ─────────────────────────────────────────────────────

  /// `POST /masters/me/documents` (multipart). Re-uploading a type replaces it.
  Future<MasterDocument> uploadDocument({
    required MasterDocumentType type,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'type': type.apiValue,
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.postMultipart('/masters/me/documents', formData);
    return MasterDocument.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /masters/me/documents`.
  Future<List<MasterDocument>> documents() async {
    final data = await _client.get('/masters/me/documents');
    return (data as List<dynamic>)
        .map((e) => MasterDocument.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /masters/me/verification/submit` — needs all required documents
  /// uploaded before moderation can start.
  Future<Master> submitVerification() async {
    final data = await _client.post('/masters/me/verification/submit');
    return Master.fromJson(data as Map<String, dynamic>);
  }
}
