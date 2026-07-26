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

  int _timezoneOffsetMinutes(String? date) {
    final localDate = date == null ? DateTime.now() : DateTime.parse(date);
    return localDate.timeZoneOffset.inMinutes;
  }

  /// `GET /clients/me/order-slots` — availability in the device's local time.
  Future<OrderSlots> slots({String? date}) async {
    final data = await _client.get(
      '/clients/me/order-slots',
      query: {
        'date': ?date,
        'timezoneOffsetMinutes': _timezoneOffsetMinutes(date),
      },
    );
    return OrderSlots.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ClientAddress>> addresses() async {
    final data = await _client.get('/clients/me/addresses');
    return (data as List<dynamic>)
        .map((e) => ClientAddress.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ClientAddress> saveAddress({
    int? id,
    required String addressText,
    String? district,
    required double latitude,
    required double longitude,
    String? details,
    bool isDefault = true,
  }) async {
    final body = <String, dynamic>{
      'addressText': addressText,
      if (district != null && district.isNotEmpty) 'district': district,
      'latitude': latitude,
      'longitude': longitude,
      if (details != null && details.isNotEmpty) 'details': details,
      'isDefault': isDefault,
    };
    final data = id == null
        ? await _client.post('/clients/me/addresses', body: body)
        : await _client.patch('/clients/me/addresses/$id', body: body);
    return ClientAddress.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /clients/me/upload/order-photo` — stages one photo, returns its key.
  Future<UploadedPhoto> uploadPhoto(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.postMultipart(
      '/clients/me/upload/order-photo',
      form,
    );
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
      'district': ?district,
      'latitude': latitude,
      'longitude': longitude,
      'timezoneOffsetMinutes': _timezoneOffsetMinutes(scheduledDate),
      if (addressDetails != null && addressDetails.isNotEmpty)
        'addressDetails': addressDetails,
      'timing': timing,
      'scheduledDate': ?scheduledDate,
      'slot': ?slot,
      'budgetMax': ?budgetMax,
      if (photoKeys.isNotEmpty) 'photoKeys': photoKeys,
      'saveToAddressBook': saveToAddressBook,
    };
    final data = await _client.post('/clients/me/orders', body: body);
    return OrderDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /clients/me/orders?status=active|done`
  Future<List<OrderSummary>> list({String? status}) async {
    final data = await _client.get(
      '/clients/me/orders',
      query: status == null ? null : {'status': status},
    );
    // Endpoint may return either a bare list or `{items, meta}`.
    final list = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? []
        : data as List<dynamic>;
    return list
        .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
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
    final data = await _client.get(
      '/clients/me/orders/$id/offers',
      query: {'sort': sort},
    );
    return (data as List<dynamic>)
        .map((e) => OfferView.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /clients/me/orders/:id/offers/:offerId/select` → assigned + chat opens.
  Future<OrderDetail> selectOffer(int orderId, int offerId) async {
    final data = await _client.post(
      '/clients/me/orders/$orderId/offers/$offerId/select',
    );
    return OrderDetail.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /clients/me/orders/:id/offers/:offerId/decline`
  Future<void> declineOffer(int orderId, int offerId) =>
      _client.post('/clients/me/orders/$orderId/offers/$offerId/decline');

  /// `POST /clients/me/orders/:id/cancel`
  Future<void> cancel(int id, {required String reason, String? note}) =>
      _client.post(
        '/clients/me/orders/$id/cancel',
        body: {
          'reason': reason,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

  /// `POST /clients/me/orders/:id/confirm-completion` → completed.
  Future<OrderDetail> confirmCompletion(int id) async {
    final data = await _client.post(
      '/clients/me/orders/$id/confirm-completion',
    );
    return OrderDetail.fromJson(data as Map<String, dynamic>);
  }
}
