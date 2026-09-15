import 'package:fixleo/core/network/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app-v2 defaults REST, docs and realtime to the test backend', () {
    expect(ApiConfig.baseUrl, 'https://test.api.fixleo.idevs.uz/api/v1');
    expect(ApiConfig.docsUrl, 'https://test.api.fixleo.idevs.uz/api/docs');
    expect(ApiConfig.socketBaseUrl, 'https://test.api.fixleo.idevs.uz');
  });
}
