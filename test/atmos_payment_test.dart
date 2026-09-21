import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';

class BankClient extends ApiClient {
  String? path;
  Object? body;
  final keys = <String?>[];
  bool pending = true;
  String? statusOverride;
  String operationStatus = 'pending';
  int? topupOperationId = 41;
  int statusOperationId = 41;
  final getPaths = <String>[];
  ApiException? statusError;
  bool lookupMissing = false;
  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    String? idempotencyKey,
  }) async {
    this.path = path;
    this.body = body;
    keys.add(idempotencyKey);
    if (path.endsWith('/bind')) {
      return {'bindingId': 'server-binding', 'phone': '***9999'};
    }
    if (path.endsWith('/confirm')) {
      return {'id': 7, 'brand': 'humo', 'last4': '4364'};
    }
    if (path.contains('/orders/') && path.endsWith('/pay')) {
      return {'id': 41, 'operationId': 41, 'status': operationStatus};
    }
    return {
      if (topupOperationId != null) 'operationId': topupOperationId,
      'status': statusOverride ?? (pending ? 'pending' : 'succeeded'),
      'balance': 1000,
    };
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    getPaths.add(path);
    if (statusError != null) throw statusError!;
    if (path.endsWith('/topup-status') && lookupMissing) return null;
    return {
      'id': statusOperationId,
      'operationId': statusOperationId,
      'status': operationStatus,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'pending intent survives reopening and uses only GET until confirmed',
    () async {
      final client = BankClient();
      final service = PaymentService(client: client);
      await expectLater(
        service.topup(cardId: 7, amount: 1000, requestKey: 'pending-key'),
        throwsA(isA<TopupPendingException>()),
      );
      final reopened = PaymentService(client: client);
      final pending = await reopened.pendingTopup();
      expect(pending?.operationId, 41);
      expect(pending?.amount, 1000);
      expect((await reopened.refreshPendingTopup())?.status, 'pending');
      expect(await reopened.pendingTopup(), isNotNull);
      client.operationStatus = 'succeeded';
      expect((await reopened.refreshPendingTopup())?.status, 'succeeded');
      expect(await reopened.pendingTopup(), isNull);
      expect(await reopened.refreshPendingTopup(), isNull);
      expect(client.keys, ['pending-key']);
      expect(client.getPaths, [
        '/clients/me/payment-operations/41',
        '/clients/me/payment-operations/41',
      ]);
      client.pending = false;
      await reopened.topup(cardId: 8, amount: 2000, requestKey: 'new-key');
      expect(client.keys, ['pending-key', 'new-key']);
    },
  );
  test(
    'status network errors and missing server records retain the intent',
    () async {
      final client = BankClient();
      final service = PaymentService(client: client);
      await expectLater(
        service.topup(cardId: 7, amount: 1000, requestKey: 'pending-key'),
        throwsA(isA<TopupPendingException>()),
      );
      for (final error in [
        const ApiException(message: 'Offline', isNetworkError: true),
        const ApiException(message: 'Not found', statusCode: 404),
      ]) {
        client.statusError = error;
        await expectLater(
          service.refreshPendingTopup(),
          throwsA(isA<ApiException>()),
        );
        expect(await service.pendingTopup(), isNotNull);
      }
      expect(client.keys.length, 1);
    },
  );
  test('a mismatched operation does not clear a payment', () async {
    final client = BankClient();
    final service = PaymentService(client: client);
    await expectLater(
      service.topup(cardId: 7, amount: 1000, requestKey: 'pending-key'),
      throwsA(isA<TopupPendingException>()),
    );
    client.statusOperationId = 999;
    client.operationStatus = 'succeeded';
    expect(await service.refreshPendingTopup(), isNull);
    expect(await service.pendingTopup(), isNotNull);
  });
  test(
    'confirmed failure clears local pending state, unknown status does not',
    () async {
      final client = BankClient();
      final service = PaymentService(client: client);
      await expectLater(
        service.topup(cardId: 7, amount: 1000, requestKey: 'pending-key'),
        throwsA(isA<TopupPendingException>()),
      );
      client.operationStatus = 'unknown';
      await service.refreshPendingTopup();
      expect(await service.pendingTopup(), isNotNull);
      client.operationStatus = 'failed';
      expect((await service.refreshPendingTopup())?.status, 'failed');
      expect(await service.pendingTopup(), isNull);
    },
  );
  test(
    'legacy intent with no operation id never triggers automatic POST',
    () async {
      final client = BankClient()..topupOperationId = null;
      final service = PaymentService(client: client);
      await expectLater(
        service.topup(cardId: 7, amount: 1000, requestKey: 'pending-key'),
        throwsA(isA<TopupPendingException>()),
      );
      expect((await service.refreshPendingTopup())?.status, 'pending');
      expect((await service.pendingTopup())?.operationId, 41);
      client.operationStatus = 'succeeded';
      await service.refreshPendingTopup();
      expect(await service.pendingTopup(), isNull);
      expect(client.getPaths, [
        '/clients/me/wallet/topup-status',
        '/clients/me/payment-operations/41',
      ]);
      expect(client.keys, ['pending-key']);
    },
  );
  test(
    'missing legacy record remains pending and never replays payment',
    () async {
      final client = BankClient()
        ..topupOperationId = null
        ..lookupMissing = true;
      final service = PaymentService(client: client);
      await expectLater(
        service.topup(cardId: 7, amount: 1000, requestKey: 'pending-key'),
        throwsA(isA<TopupPendingException>()),
      );
      expect(await service.refreshPendingTopup(), isNull);
      expect(await service.pendingTopup(), isNotNull);
      expect(client.keys, ['pending-key']);
    },
  );
  test(
    'terminal failure is shown as an error and allows a new intent',
    () async {
      final client = BankClient()..statusOverride = 'failed';
      final service = PaymentService(client: client);
      await expectLater(
        service.topup(cardId: 7, amount: 1000, requestKey: 'failed-key'),
        throwsA(isA<ApiException>()),
      );
      client.statusOverride = 'succeeded';
      expect(
        await service.topup(cardId: 8, amount: 2000, requestKey: 'new-key'),
        1000,
      );
      expect(client.keys, ['failed-key', 'new-key']);
    },
  );
  test('unrecognized status preserves the original intent', () async {
    final client = BankClient()..statusOverride = 'unknown';
    final service = PaymentService(client: client);
    await expectLater(
      service.topup(cardId: 7, amount: 1000, requestKey: 'original-key'),
      throwsA(isA<ApiException>()),
    );
    client.statusOverride = 'succeeded';
    await service.topup(
      cardId: 7,
      amount: 1000,
      requestKey: 'must-not-be-used',
    );
    expect(client.keys, ['original-key', 'original-key']);
  });
  test(
    'binding sends full card to protected backend and OTP only at confirmation',
    () async {
      final client = BankClient();
      final service = PaymentService(kind: 'master', client: client);
      await service.bindCard('9860090101014364', '2802');
      expect(client.path, '/masters/me/cards/bind');
      expect(client.body, {'cardNumber': '9860090101014364', 'expiry': '2802'});
      final card = await service.confirmCard('server-binding', '123456');
      expect(client.path, '/masters/me/cards/confirm');
      expect(client.body, {'bindingId': 'server-binding', 'otp': '123456'});
      expect(card.id, 7);
    },
  );
  test(
    'pending topup is not presented as successful and reuses key after reopening',
    () async {
      final client = BankClient();
      final service = PaymentService(client: client);
      await expectLater(
        service.topup(
          cardId: 7,
          amount: 1000,
          requestKey: 'original-request-key',
        ),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        PaymentService(
          client: client,
        ).topup(cardId: 7, amount: 1000, requestKey: 'different-request-key'),
        throwsA(isA<ApiException>()),
      );
      expect(client.keys, ['original-request-key', 'original-request-key']);
      await expectLater(
        service.topup(
          cardId: 7,
          amount: 2000,
          requestKey: 'changed-amount-key',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(client.keys.length, 2);
      client.pending = false;
      expect(
        await service.topup(
          cardId: 7,
          amount: 1000,
          requestKey: 'ignored-request-key',
        ),
        1000,
      );
      expect(client.keys.last, 'original-request-key');
      expect(
        await service.topup(
          cardId: 7,
          amount: 1000,
          requestKey: 'next-payment-key',
        ),
        1000,
      );
      expect(client.keys.last, 'next-payment-key');
    },
  );
  test(
    'order payment exposes its durable operation for GET-only recovery',
    () async {
      final client = BankClient();
      final service = PaymentService(client: client);
      final pending = await service.pay(22, 7);
      expect(pending.operationId, 41);
      expect(pending.status, 'pending');
      expect(client.path, '/clients/me/orders/22/pay');

      client.operationStatus = 'succeeded';
      final recovered = await service.paymentOperation(pending.operationId);
      expect(recovered.operationId, 41);
      expect(recovered.status, 'succeeded');
      expect(client.path, '/clients/me/payment-operations/41');
    },
  );
}
