import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/features/auth/data/client_auth_service.dart';
import 'package:fixleo/features/master/data/master_service.dart';

class _CaptureAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'expiresInSeconds': 300},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _api(_CaptureAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      validateStatus: (_) => true,
      contentType: Headers.jsonContentType,
    ),
  );
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio, refreshDio: dio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('client OTP requests include the selected SMS language', () async {
    final adapter = _CaptureAdapter();
    final service = ClientAuthService(client: _api(adapter));
    LocaleController.language.value = AppLanguage.ru;

    await service.sendOtp('+998901234567');
    await service.resendOtp('+998901234567');

    expect(adapter.requests.map((request) => request.path), [
      '/clients/auth/send-otp',
      '/clients/auth/resend-otp',
    ]);
    for (final request in adapter.requests) {
      expect(request.data, {'phone': '+998901234567', 'language': 'ru'});
      expect(request.headers['Accept-Language'], 'ru');
    }
  });

  test('master OTP requests include the selected SMS language', () async {
    final adapter = _CaptureAdapter();
    final service = MasterService(client: _api(adapter));
    LocaleController.language.value = AppLanguage.en;

    await service.sendOtp('+998901234567');
    await service.resendOtp('+998901234567');

    expect(adapter.requests.map((request) => request.path), [
      '/masters/auth/send-otp',
      '/masters/auth/resend-otp',
    ]);
    for (final request in adapter.requests) {
      expect(request.data, {'phone': '+998901234567', 'language': 'en'});
      expect(request.headers['Accept-Language'], 'en');
    }
  });
}
