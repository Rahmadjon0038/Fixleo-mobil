import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/network/api_config.dart';

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

class SavedCard {
  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    this.isDefault = false,
  });
  final int id;
  final String brand;
  final String last4;
  final bool isDefault;
  factory SavedCard.fromJson(Map<String, dynamic> j) => SavedCard(
    id: _int(j['id']),
    brand: j['brand'] as String? ?? '',
    last4: j['last4'] as String? ?? '',
    isDefault: j['isDefault'] == true,
  );
}

class OrderPaymentInfo {
  const OrderPaymentInfo({
    required this.orderId,
    required this.orderTitle,
    required this.amount,
    this.paymentStatus,
    this.cards = const [],
  });
  final int orderId;
  final String orderTitle;
  final int amount;
  final String? paymentStatus;
  final List<SavedCard> cards;
  factory OrderPaymentInfo.fromJson(Map<String, dynamic> j) => OrderPaymentInfo(
    orderId: _int(j['orderId']),
    orderTitle: j['orderTitle'] as String? ?? '',
    amount: _int(j['amount']),
    paymentStatus: j['paymentStatus'] as String?,
    cards: (j['cards'] as List<dynamic>? ?? [])
        .map((e) => SavedCard.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}

class PaymentAttempt {
  const PaymentAttempt({required this.operationId, required this.status});

  final int operationId;
  final String status;

  factory PaymentAttempt.fromJson(Map<String, dynamic> json) => PaymentAttempt(
    operationId: _int(json['operationId'] ?? json['id']),
    status: json['status'] as String? ?? 'pending',
  );
}

/// A durable intent, not proof that the bank has debited the card.
class PendingTopup {
  const PendingTopup({
    required this.key,
    required this.cardId,
    required this.amount,
    this.operationId,
  });

  final String key;
  final int cardId;
  final int amount;
  final int? operationId;

  factory PendingTopup.fromJson(Map<String, dynamic> json) => PendingTopup(
    key: json['key'] as String,
    cardId: _int(json['cardId']),
    amount: _int(json['amount']),
    operationId: _int(json['operationId']) > 0
        ? _int(json['operationId'])
        : null,
  );
}

/// Pending is informational; the wallet must not render it as a payment error.
class TopupPendingException extends ApiException {
  const TopupPendingException({required super.message});
}

/// Client cards + order payment (see docs/v3/Payments.md). Cards live under
/// `/{kind}s/me/cards`; [kind] lets masters reuse this for their payout cards.
class PaymentService {
  PaymentService({this.kind = 'client', ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final String kind; // 'client' | 'master'
  final ApiClient _client;

  String get _topupStorageKey =>
      'atmos_topup_${ApiConfig.baseUrl}_${AuthSession.instance.subjectId}';

  Future<PendingTopup?> pendingTopup() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_topupStorageKey);
    if (value == null) return null;
    return PendingTopup.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  /// Only reads an existing operation. Never POSTs/replays a debit to poll it.
  /// Legacy intents are resolved by their original key using another GET endpoint.
  Future<PaymentAttempt?> refreshPendingTopup() async {
    final storageKey = _topupStorageKey;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(storageKey);
    if (value == null) return null;
    final pending = PendingTopup.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
    PaymentAttempt attempt;
    if (pending.operationId == null) {
      final data = await _client.get(
        '/clients/me/wallet/topup-status',
        query: {'requestKey': pending.key},
      );
      if (data == null) return null;
      attempt = PaymentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
    } else {
      attempt = await paymentOperation(pending.operationId!);
      if (attempt.operationId != pending.operationId) return null;
    }
    if (attempt.operationId <= 0) return null;
    if (storageKey != _topupStorageKey ||
        prefs.getString(storageKey) != value) {
      return null;
    }
    if (attempt.status == 'succeeded' || attempt.status == 'failed') {
      // A response from an older account/intent cannot clear a newer payment.
      await prefs.remove(storageKey);
    } else if (pending.operationId == null) {
      await prefs.setString(
        storageKey,
        jsonEncode({
          ...jsonDecode(value) as Map<String, dynamic>,
          'operationId': attempt.operationId,
        }),
      );
    }
    return storageKey == _topupStorageKey ? attempt : null;
  }

  Future<Map<String, dynamic>> bindCard(String number, String expiry) async =>
      Map<String, dynamic>.from(
        await _client.post(
              '/${kind}s/me/cards/bind',
              body: {'cardNumber': number, 'expiry': expiry},
            )
            as Map,
      );

  Future<SavedCard> confirmCard(String bindingId, String otp) async =>
      SavedCard.fromJson(
        Map<String, dynamic>.from(
          await _client.post(
                '/${kind}s/me/cards/confirm',
                body: {'bindingId': bindingId, 'otp': otp},
              )
              as Map,
        ),
      );

  Future<List<SavedCard>> cards() async {
    final data = await _client.get('/${kind}s/me/cards');
    return (data as List<dynamic>)
        .map((e) => SavedCard.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<SavedCard> addCard({
    required String brand,
    required String last4,
    String? expiry,
  }) async {
    final data = await _client.post(
      '/${kind}s/me/cards',
      body: {
        'brand': brand,
        'last4': last4,
        if (expiry != null && expiry.isNotEmpty) 'expiry': expiry,
      },
    );
    return SavedCard.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteCard(int id) => _client.delete('/${kind}s/me/cards/$id');

  Future<void> setDefault(int id) =>
      _client.post('/${kind}s/me/cards/$id/default');

  // ---- order payment (client only) ----

  Future<OrderPaymentInfo> paymentInfo(int orderId) async {
    final data = await _client.get('/clients/me/orders/$orderId/payment');
    return OrderPaymentInfo.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /clients/me/orders/:id/pay` returns the durable ATMOS operation.
  Future<PaymentAttempt> pay(int orderId, int cardId) async {
    final data = await _client.post(
      '/clients/me/orders/$orderId/pay',
      body: {'cardId': cardId},
    );
    return PaymentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// GET-only provider recovery. It never creates or reapplies a charge.
  Future<PaymentAttempt> paymentOperation(int operationId) async {
    final data = await _client.get(
      '/clients/me/payment-operations/$operationId',
    );
    return PaymentAttempt.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ---- client wallet (FINAL «Кошелек») ----

  /// `GET /clients/me/wallet` → balance in so'm.
  Future<int> walletBalance() async {
    final data = await _client.get('/clients/me/wallet');
    return _int((data as Map<String, dynamic>)['balance']);
  }

  /// `GET /clients/me/wallet/operations` — merged money history, newest first.
  Future<List<WalletOperation>> walletOperations() async {
    final data = await _client.get('/clients/me/wallet/operations');
    return (data as List<dynamic>)
        .map((e) => WalletOperation.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /clients/me/wallet/topup` → new balance.
  Future<int> topup({
    required int cardId,
    required int amount,
    required String requestKey,
  }) async {
    // Preserve the same intent across closing/reopening the sheet or restarting the app.
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _topupStorageKey;
    final previous = prefs.getString(storageKey);
    if (previous != null) {
      final pending = jsonDecode(previous) as Map<String, dynamic>;
      if (pending['cardId'] != cardId || pending['amount'] != amount) {
        throw TopupPendingException(
          message: tr(
            LocaleController.language.value,
            'Avvalgi to‘lov tasdiqlanmoqda. Natijani hamyonda kuzatishingiz mumkin. Qayta to‘lamang.',
            'Предыдущий платёж подтверждается. Следите за статусом в кошельке. Не платите повторно.',
            'Your previous payment is being confirmed. Follow its status in your wallet. Do not pay again.',
          ),
        );
      }
      requestKey = pending['key'] as String;
    } else {
      await prefs.setString(
        storageKey,
        jsonEncode({'key': requestKey, 'cardId': cardId, 'amount': amount}),
      );
    }
    final data = await _client.post(
      '/clients/me/wallet/topup',
      body: {'cardId': cardId, 'amount': amount},
      idempotencyKey: requestKey,
    );
    final status = (data as Map<String, dynamic>)['status'];
    final operationId = _int(data['operationId'] ?? data['id']);
    final currentIntent = prefs.getString(storageKey);
    final ownsIntent =
        currentIntent != null &&
        (jsonDecode(currentIntent) as Map<String, dynamic>)['key'] ==
            requestKey;
    // Status polling may have completed this intent while POST was in flight.
    // Do not resurrect it or overwrite a newer payment's persisted key.
    if (operationId > 0 && ownsIntent) {
      await prefs.setString(
        storageKey,
        jsonEncode({
          'key': requestKey,
          'cardId': cardId,
          'amount': amount,
          'operationId': operationId,
        }),
      );
    }
    if (status == 'failed') {
      // Only the backend may declare a safe terminal failure. Release the
      // persisted intent so reopening the form can use a new card/request key.
      if (ownsIntent) await prefs.remove(storageKey);
      throw ApiException(
        message: tr(
          LocaleController.language.value,
          'To‘lov amalga oshmadi. Oynani yopib, boshqa karta bilan qayta urinishingiz mumkin.',
          'Платёж не выполнен. Закройте окно и попробуйте снова с другой картой.',
          'Payment failed. Close this form and try again with another card.',
        ),
      );
    }
    if (status != null && status != 'succeeded') {
      throw TopupPendingException(
        message: tr(
          LocaleController.language.value,
          'To‘lov tasdiqlanmoqda. Bu bir necha daqiqa olishi mumkin. Balans avtomatik yangilanadi. Qayta to‘lamang.',
          'Платёж подтверждается. Это может занять несколько минут. Баланс обновится автоматически. Не платите повторно.',
          'Your payment is being confirmed. This may take a few minutes. Your balance will update automatically. Do not pay again.',
        ),
      );
    }
    if (ownsIntent) await prefs.remove(storageKey);
    return _int(data['balance']);
  }
}

/// One row of the client's «Операции» list.
class WalletOperation {
  const WalletOperation({
    required this.id,
    required this.kind,
    required this.amount,
    this.orderTitle,
    this.categoryName,
    this.note,
    this.createdAt,
  });

  final String id;

  /// topup | order_payment | refund | adjustment | card_payment | card_refund
  final String kind;

  /// Signed so'm amount (+ credit / − debit).
  final int amount;
  final String? orderTitle;
  final String? categoryName;
  final String? note;
  final DateTime? createdAt;

  factory WalletOperation.fromJson(Map<String, dynamic> j) => WalletOperation(
    id: j['id']?.toString() ?? '',
    kind: j['kind'] as String? ?? '',
    amount: _int(j['amount']),
    orderTitle: j['orderTitle'] as String?,
    categoryName: j['categoryName'] as String?,
    note: j['note'] as String?,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
  );
}
