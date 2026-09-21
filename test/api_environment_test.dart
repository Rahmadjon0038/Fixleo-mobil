import 'package:fixleo/core/network/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release defaults REST, docs and realtime to the production backend',
    () {
      expect(ApiConfig.baseUrl, 'https://api.fixleo.com/api/v1');
      expect(ApiConfig.docsUrl, 'https://api.fixleo.com/api/docs');
      expect(ApiConfig.socketBaseUrl, 'https://api.fixleo.com');
    },
  );
}
