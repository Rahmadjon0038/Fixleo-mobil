import 'package:dio/dio.dart';

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';

/// Master feed + offers + jobs + wallet (see docs/v3/Orders.md, Payments.md).
/// All calls need an approved-master token (handled by [ApiClient]).
class MasterMarketplaceService {
  MasterMarketplaceService({ApiClient? client})
    : _client = client ?? ApiClient.instance;
  final ApiClient _client;

  // ------------------------------------------------------------- feed

  /// `GET /masters/me/feed?categories=&radiusKm=&sort=`
  Future<List<FeedItem>> feed({
    List<int> categoryIds = const [],
    int radiusKm = 10,
    String sort = 'new',
  }) async {
    final data = await _client.get(
      '/masters/me/feed',
      query: {
        if (categoryIds.isNotEmpty) 'categories': categoryIds.join(','),
        'radiusKm': radiusKm,
        'sort': sort,
      },
    );
    final list = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? []
        : data as List<dynamic>;
    return list
        .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /masters/me/feed/count` — live result count for the filter button.
  Future<int> feedCount({
    List<int> categoryIds = const [],
    int radiusKm = 10,
    String sort = 'new',
  }) async {
    final data = await _client.get(
      '/masters/me/feed/count',
      query: {
        if (categoryIds.isNotEmpty) 'categories': categoryIds.join(','),
        'radiusKm': radiusKm,
        'sort': sort,
      },
    );
    return (data as Map<String, dynamic>)['total'] as int? ?? 0;
  }

  /// `GET /masters/me/feed/:orderId`
  Future<FeedDetail> feedDetail(int orderId) async {
    final data = await _client.get('/masters/me/feed/$orderId');
    return FeedDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /masters/me/feed/:orderId/decline`
  Future<void> decline(int orderId, String reason) => _client.post(
    '/masters/me/feed/$orderId/decline',
    body: {'reason': reason},
  );

  /// `POST /masters/me/feed/:orderId/offer`
  Future<void> makeOffer(
    int orderId, {
    required String priceType, // fixed | range | after_inspection
    int? price,
    String? comment,
  }) => _client.post(
    '/masters/me/feed/$orderId/offer',
    body: {
      'priceType': priceType,
      if (priceType != 'after_inspection' && price != null) 'price': price,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    },
  );

  /// `GET /masters/me/offers?status=`
  Future<List<MyOffer>> myOffers({String? status}) async {
    final data = await _client.get(
      '/masters/me/offers',
      query: status == null ? null : {'status': status},
    );
    return (data as List<dynamic>)
        .map((e) => MyOffer.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> withdrawOffer(int offerId) =>
      _client.delete('/masters/me/offers/$offerId');

  // ------------------------------------------------------------- jobs

  /// `GET /masters/me/orders?status=current|history`
  Future<List<MasterOrder>> orders({String status = 'current'}) async {
    final data = await _client.get(
      '/masters/me/orders',
      query: {'status': status},
    );
    final list = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? []
        : data as List<dynamic>;
    return list
        .map((e) => MasterOrder.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<MasterOrderDetail> orderDetail(int id) async {
    final data = await _client.get('/masters/me/orders/$id');
    return MasterOrderDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /masters/me/orders/:id/status` — `to`: on_the_way | arrived.
  Future<MasterOrderDetail> setStatus(int id, String to) async {
    final data = await _client.post(
      '/masters/me/orders/$id/status',
      body: {'to': to},
    );
    return MasterOrderDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<MasterOrderDetail?> respondToInvitation(
    int id, {
    required bool accept,
  }) async {
    final data = await _client.post(
      '/masters/me/orders/$id/invitation/respond',
      body: {'accept': accept},
    );
    if (!accept) return null;
    return MasterOrderDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /masters/me/orders/:id/complete`
  Future<void> complete(
    int id, {
    int? finalAmount,
    List<String> photoKeys = const [],
  }) => _client.post(
    '/masters/me/orders/$id/complete',
    body: {
      'finalAmount': ?finalAmount,
      if (photoKeys.isNotEmpty) 'photoKeys': photoKeys,
    },
  );

  /// `POST /masters/me/upload/order-photo` — stages one real after-work photo.
  Future<String> uploadOrderPhoto(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.postMultipart(
      '/masters/me/upload/order-photo',
      form,
    );
    return (data as Map<String, dynamic>)['fileKey'] as String;
  }

  Future<void> cancel(int id, {required String reason, String? note}) =>
      _client.post(
        '/masters/me/orders/$id/cancel',
        body: {
          'reason': reason,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

  /// `POST /masters/me/location` — live location ping while on the way.
  Future<void> pingLocation({
    required int orderId,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? headingDegrees,
    double? speedMps,
  }) {
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };
    if (accuracyMeters != null) body['accuracyMeters'] = accuracyMeters;
    if (headingDegrees != null) body['headingDegrees'] = headingDegrees;
    if (speedMps != null) body['speedMps'] = speedMps;
    return _client.post('/masters/me/orders/$orderId/location', body: body);
  }

  // ------------------------------------------------------------- wallet

  Future<MasterWallet> wallet() async {
    final data = await _client.get('/masters/me/wallet');
    return MasterWallet.fromJson(data as Map<String, dynamic>);
  }

  Future<List<WalletTx>> transactions() async {
    final data = await _client.get('/masters/me/wallet/transactions');
    return (data as List<dynamic>)
        .map((e) => WalletTx.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // ------------------------------------------------------------- reviews

  /// `GET /masters/me/reviews?page=` — real reviews and rating histogram.
  Future<MasterReviews> reviews({int page = 1}) async {
    final data = await _client.get(
      '/masters/me/reviews',
      query: {'page': page},
    );
    return MasterReviews.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /masters/me/withdrawals` — `mode`: instant | standard.
  Future<void> withdraw({
    required int amount,
    required int cardId,
    String mode = 'standard',
  }) => _client.post(
    '/masters/me/withdrawals',
    body: {'amount': amount, 'cardId': cardId, 'mode': mode},
  );

  // ------------------------------------------------------------- portfolio

  Future<void> addPortfolio(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    await _client.postMultipart('/masters/me/portfolio', form);
  }

  Future<void> removePortfolio(int id) =>
      _client.delete('/masters/me/portfolio/$id');
}
