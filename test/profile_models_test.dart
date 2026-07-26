import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/features/auth/data/client_model.dart';
import 'package:fixleo/features/master/data/master_model.dart';

void main() {
  group('profile media URL parsing', () {
    test('resolves a root-relative avatar against the API origin', () {
      expect(
        ApiConfig.resolveMediaUrl('/api/v1/profile-avatars/client/7?v=1'),
        'https://api.fixleo.com/api/v1/profile-avatars/client/7?v=1',
      );
      expect(
        ApiConfig.resolveMediaUrl('https://cdn.fixleo.com/avatar.jpg'),
        'https://cdn.fixleo.com/avatar.jpg',
      );
      expect(ApiConfig.resolveMediaUrl(null), isNull);
    });

    test('client parses editable profile fields and avatar', () {
      final client = Client.fromJson({
        'id': '#U-00000000007',
        'phone': '+998901234567',
        'status': 'active',
        'name': 'Hojiakbar',
        'birthDate': '1995-05-15',
        'gender': 'male',
        'avatarUrl': '/api/v1/profile-avatars/client/7?v=1',
      });

      expect(client.birthDate, DateTime(1995, 5, 15));
      expect(client.gender, 'male');
      expect(
        client.avatarUrl,
        'https://api.fixleo.com/api/v1/profile-avatars/client/7?v=1',
      );
    });

    test('master parses its persisted avatar', () {
      final master = Master.fromJson({
        'id': '#M-00000000003',
        'phone': '+998901234567',
        'status': 'active',
        'verificationStatus': 'approved',
        'avatarUrl': '/api/v1/profile-avatars/master/3?v=1',
      });

      expect(
        master.avatarUrl,
        'https://api.fixleo.com/api/v1/profile-avatars/master/3?v=1',
      );
    });
  });
}
