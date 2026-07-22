import 'package:fixleo/core/network/api_client.dart';

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

/// Client cards + order payment (see docs/v3/Payments.md). Cards live under
/// `/{kind}s/me/cards`; [kind] lets masters reuse this for their payout cards.
class PaymentService {
  PaymentService({this.kind = 'client', ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final String kind; // 'client' | 'master'
  final ApiClient _client;

  Future<List<SavedCard>> cards() async {
    final data = await _client.get('/${kind}s/me/cards');
    return (data as List<dynamic>)
        .map((e) => SavedCard.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<SavedCard> addCard({required String brand, required String last4, String? expiry}) async {
    final data = await _client.post('/${kind}s/me/cards', body: {
      'brand': brand,
      'last4': last4,
      if (expiry != null && expiry.isNotEmpty) 'expiry': expiry,
    });
    return SavedCard.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteCard(int id) => _client.delete('/${kind}s/me/cards/$id');

  Future<void> setDefault(int id) => _client.post('/${kind}s/me/cards/$id/default');

  // ---- order payment (client only) ----

  Future<OrderPaymentInfo> paymentInfo(int orderId) async {
    final data = await _client.get('/clients/me/orders/$orderId/payment');
    return OrderPaymentInfo.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /clients/me/orders/:id/pay` → `{status, masterShare?}`.
  Future<String> pay(int orderId, int cardId) async {
    final data = await _client.post('/clients/me/orders/$orderId/pay', body: {'cardId': cardId});
    return (data as Map<String, dynamic>)['status'] as String? ?? 'unknown';
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
  Future<int> topup({required int cardId, required int amount}) async {
    final data = await _client
        .post('/clients/me/wallet/topup', body: {'cardId': cardId, 'amount': amount});
    return _int((data as Map<String, dynamic>)['balance']);
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
