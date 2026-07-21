import 'package:dio/dio.dart';

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/features/request/data/order_models.dart';

/// Client marketplace endpoints — orders, offers, slots, addresses, tracking
/// (see docs/v3/Orders.md). Every call needs a client token (handled by
/// [ApiClient] via [AuthSession]).
class OrderService {
  OrderService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  // ------------------------------------------------------------- discovery

  /// `GET /clients/me/order-slots?date=YYYY-MM-DD` — the single source of truth
  /// for which time slots are still bookable.
  Future<OrderSlots> slots({String? date}) async {
    final data = await _client.get('/clients/me/order-slots',
        query: date == null ? null : {'date': date});
    return OrderSlots.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /clients/me/address-check` → whether the point is inside the service area.
  Future<bool> addressAvailable({required double latitude, required double longitude}) async {
    final data = await _client.post('/clients/me/address-check',
        body: {'latitude': latitude, 'longitude': longitude});
    return (data as Map<String, dynamic>)['available'] == true;
  }

  /// `POST /clients/me/upload/order-photo` — stages one photo, returns its key.
  Future<UploadedPhoto> uploadPhoto(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.postMultipart('/clients/me/upload/order-photo', form);
    return UploadedPhoto.fromJson(data as Map<String, dynamic>);
  }

  // ------------------------------------------------------------- orders

  /// `POST /clients/me/orders` — create a new request.
  Future<OrderDetail> create({
    required int categoryId,
    required String description,
    required String addressText,
    String? district,
    required double latitude,
    required double longitude,
    String? addressDetails,
    required String timing, // asap | today | scheduled
    String? scheduledDate, // YYYY-MM-DD (today/scheduled)
    String? slot, // s10_12 | s12_15 | s15_18 | s18_21
    int? budgetMax,
    List<String> photoKeys = const [],
    bool saveToAddressBook = false,
  }) async {
    final body = <String, dynamic>{
      'categoryId': categoryId,
      'description': description,
      'addressText': addressText,
      if (district != null) 'district': district,
      'latitude': latitude,
      'longitude': longitude,
      if (addressDetails != null && addressDetails.isNotEmpty) 'addressDetails': addressDetails,
      'timing': timing,
      if (scheduledDate != null) 'scheduledDate': scheduledDate,
      if (slot != null) 'slot': slot,
      if (budgetMax != null) 'budgetMax': budgetMax,
      if (photoKeys.isNotEmpty) 'photoKeys': photoKeys,
      'saveToAddressBook': saveToAddressBook,
    };
    final data = await _client.post('/clients/me/orders', body: body);
    return OrderDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /clients/me/orders?status=active|done`
  Future<List<OrderSummary>> list({String? status}) async {
    final data = await _client.get('/clients/me/orders',
        query: status == null ? null : {'status': status});
    // Endpoint may return either a bare list or `{items, meta}`.
    final list = data is Map<String, dynamic> ? data['items'] as List<dynamic>? ?? [] : data as List<dynamic>;
    return list.map((e) => OrderSummary.fromJson(e as Map<String, dynamic>)).toList(growable: false);
  }

  /// `GET /clients/me/orders/:id`
  Future<OrderDetail> detail(int id) async {
    final data = await _client.get('/clients/me/orders/$id');
    return OrderDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /clients/me/orders/:id/track` — live status + master location + ETA.
  Future<TrackInfo> track(int id) async {
    final data = await _client.get('/clients/me/orders/$id/track');
    return TrackInfo.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /clients/me/orders/:id/offers?sort=rating|price|distance`
  Future<List<OfferView>> offers(int id, {String sort = 'rating'}) async {
    final data = await _client.get('/clients/me/orders/$id/offers', query: {'sort': sort});
    return (data as List<dynamic>)
        .map((e) => OfferView.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /clients/me/orders/:id/offers/:offerId/select` → assigned + chat opens.
  Future<OrderDetail> selectOffer(int orderId, int offerId) async {
    final data = await _client.post('/clients/me/orders/$orderId/offers/$offerId/select');
    return OrderDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /clients/me/orders/:id/offers/:offerId/decline`
  Future<void> declineOffer(int orderId, int offerId) =>
      _client.post('/clients/me/orders/$orderId/offers/$offerId/decline');

  /// `POST /clients/me/orders/:id/cancel`
  Future<void> cancel(int id, {required String reason, String? note}) =>
      _client.post('/clients/me/orders/$id/cancel',
          body: {'reason': reason, if (note != null && note.isNotEmpty) 'note': note});

  /// `POST /clients/me/orders/:id/confirm-completion` → completed.
  Future<OrderDetail> confirmCompletion(int id) async {
    final data = await _client.post('/clients/me/orders/$id/confirm-completion');
    return OrderDetail.fromJson(data as Map<String, dynamic>);
  }
}
