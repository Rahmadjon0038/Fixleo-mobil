import 'package:fixleo/core/network/api_config.dart';

/// Client-side marketplace models. Field names mirror the backend response
/// DTOs exactly (see docs/v3/Orders.md) so `fromJson` is a direct mapping.

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _intN(dynamic v) => (v as num?)?.toInt();
double? _dbl(dynamic v) => (v as num?)?.toDouble();

class ClientAddress {
  const ClientAddress({
    required this.id,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    this.label,
    this.district,
    this.details,
    this.isDefault = false,
  });

  final int id;
  final String addressText;
  final double latitude;
  final double longitude;
  final String? label;
  final String? district;
  final String? details;
  final bool isDefault;

  factory ClientAddress.fromJson(Map<String, dynamic> j) => ClientAddress(
    id: _int(j['id']),
    addressText: j['addressText'] as String? ?? '',
    latitude: _dbl(j['latitude']) ?? 0,
    longitude: _dbl(j['longitude']) ?? 0,
    label: j['label'] as String?,
    district: j['district'] as String?,
    details: j['details'] as String?,
    isDefault: j['isDefault'] == true,
  );
}

/// A row in the client's "Мои заказы" list.
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.title,
    required this.status,
    this.masterName,
    this.price,
    this.offersCount = 0,
    this.createdAt,
  });

  final int id;
  final String title;
  final String status;
  final String? masterName;
  final int? price;
  final int offersCount;
  final DateTime? createdAt;

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
    id: _int(j['id']),
    title: j['title'] as String? ?? '',
    status: j['status'] as String? ?? '',
    masterName: j['masterName'] as String?,
    price: _intN(j['price']),
    offersCount: _int(j['offersCount']),
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
  );
}

class OrderMasterInfo {
  const OrderMasterInfo({
    required this.numericId,
    this.name,
    this.avatarUrl,
    this.ratingAvg,
    this.phone,
    this.categoryName,
  });

  final int numericId;
  final String? name;
  final String? avatarUrl;
  final double? ratingAvg;
  final String? phone;
  final String? categoryName;

  factory OrderMasterInfo.fromJson(Map<String, dynamic> j) => OrderMasterInfo(
    numericId: _int(j['numericId']),
    name: j['name'] as String?,
    avatarUrl: ApiConfig.resolveMediaUrl(j['avatarUrl']),
    ratingAvg: _dbl(j['ratingAvg']),
    phone: j['phone'] as String?,
    categoryName: j['categoryName'] as String?,
  );
}

class OrderPhoto {
  const OrderPhoto({required this.id, required this.kind, required this.url});
  final int id;
  final String kind;
  final String url;
  factory OrderPhoto.fromJson(Map<String, dynamic> j) => OrderPhoto(
    id: _int(j['id']),
    kind: j['kind'] as String? ?? '',
    url: ApiConfig.resolveMediaUrl(j['url']) ?? '',
  );
}

class OrderTimelineEntry {
  const OrderTimelineEntry({required this.to, this.at});
  final String to;
  final DateTime? at;
  factory OrderTimelineEntry.fromJson(Map<String, dynamic> j) =>
      OrderTimelineEntry(
        to: j['to'] as String? ?? '',
        at: DateTime.tryParse(j['at']?.toString() ?? ''),
      );
}

class OrderCapabilities {
  const OrderCapabilities({
    this.canCancel = false,
    this.canConfirm = false,
    this.canDispute = false,
    this.canReview = false,
    this.canPay = false,
  });

  final bool canCancel;
  final bool canConfirm;
  final bool canDispute;
  final bool canReview;
  final bool canPay;

  factory OrderCapabilities.fromJson(Map<String, dynamic>? j) =>
      OrderCapabilities(
        canCancel: j?['canCancel'] == true,
        canConfirm: j?['canConfirm'] == true,
        canDispute: j?['canDispute'] == true,
        canReview: j?['canReview'] == true,
        canPay: j?['canPay'] == true,
      );
}

/// Full order detail (client view) — the c11 tracking screen.
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.addressText,
    this.latitude,
    this.longitude,
    this.slotLabel,
    this.timing = '',
    this.scheduledDate,
    this.agreedPrice,
    this.finalAmount,
    this.photos = const [],
    this.timeline = const [],
    this.offersCount = 0,
    this.master,
    this.conversationId,
    this.paymentStatus,
    this.paymentAmount,
    this.reviewId,
    this.complaintId,
    this.complaintStatus,
    this.capabilities = const OrderCapabilities(),
    this.matchedMastersCount,
  });

  final int id;
  final String title;
  final String description;
  final String status;
  final String addressText;
  final double? latitude;
  final double? longitude;
  final String? slotLabel;
  final String timing;
  final String? scheduledDate;
  final int? agreedPrice;
  final int? finalAmount;
  final List<OrderPhoto> photos;
  final List<OrderTimelineEntry> timeline;
  final int offersCount;
  final OrderMasterInfo? master;
  final int? conversationId;
  final String? paymentStatus;
  final int? paymentAmount;
  final int? reviewId;
  final int? complaintId;
  final String? complaintStatus;
  final OrderCapabilities capabilities;
  final int? matchedMastersCount;

  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    final payment = j['payment'] as Map<String, dynamic>?;
    final review = j['review'] as Map<String, dynamic>?;
    final complaint = j['complaint'] as Map<String, dynamic>?;
    return OrderDetail(
      id: _int(j['id']),
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      status: j['status'] as String? ?? '',
      addressText: j['addressText'] as String? ?? '',
      latitude: _dbl(j['latitude']),
      longitude: _dbl(j['longitude']),
      slotLabel: j['slotLabel'] as String?,
      timing: j['timing'] as String? ?? '',
      scheduledDate: j['scheduledDate'] as String?,
      agreedPrice: _intN(j['agreedPrice']),
      finalAmount: _intN(j['finalAmount']),
      photos: (j['photos'] as List<dynamic>? ?? [])
          .map((e) => OrderPhoto.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      timeline: (j['timeline'] as List<dynamic>? ?? [])
          .map((e) => OrderTimelineEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      offersCount: _int(j['offersCount']),
      master: j['master'] == null
          ? null
          : OrderMasterInfo.fromJson(j['master'] as Map<String, dynamic>),
      conversationId: _intN(j['conversationId']),
      paymentStatus: payment?['status'] as String?,
      paymentAmount: _intN(payment?['amount']),
      reviewId: _intN(review?['id']),
      complaintId: _intN(complaint?['id']),
      complaintStatus: complaint?['status'] as String?,
      capabilities: OrderCapabilities.fromJson(
        j['capabilities'] as Map<String, dynamic>?,
      ),
      matchedMastersCount: _intN(j['matchedMastersCount']),
    );
  }
}

/// One master's response to an order (c06 responses list).
class OfferView {
  const OfferView({
    required this.id,
    required this.priceType,
    this.price,
    this.comment,
    this.distanceKm = 0,
    required this.masterId,
    this.masterName,
    this.ratingAvg,
    this.ratingCount = 0,
    this.completedOrders = 0,
  });

  final int id;
  final String priceType;
  final int? price;
  final String? comment;
  final double distanceKm;
  final int masterId;
  final String? masterName;
  final double? ratingAvg;
  final int ratingCount;
  final int completedOrders;

  factory OfferView.fromJson(Map<String, dynamic> j) {
    final m = j['master'] as Map<String, dynamic>? ?? const {};
    return OfferView(
      id: _int(j['id']),
      priceType: j['priceType'] as String? ?? 'fixed',
      price: _intN(j['price']),
      comment: j['comment'] as String?,
      distanceKm: _dbl(j['distanceKm']) ?? 0,
      masterId: _int(m['numericId']),
      masterName: m['name'] as String?,
      ratingAvg: _dbl(m['ratingAvg']),
      ratingCount: _int(m['ratingCount']),
      completedOrders: _int(m['completedOrders']),
    );
  }
}

/// A bookable time slot for the "when" step.
class OrderSlot {
  const OrderSlot({
    required this.slot,
    required this.label,
    required this.available,
  });
  final String slot;
  final String label;
  final bool available;
  factory OrderSlot.fromJson(Map<String, dynamic> j) => OrderSlot(
    slot: j['slot'] as String? ?? '',
    label: j['label'] as String? ?? '',
    available: j['available'] != false,
  );
}

class OrderSlots {
  const OrderSlots({
    required this.date,
    required this.asapAvailable,
    required this.slots,
  });
  final String date;
  final bool asapAvailable;
  final List<OrderSlot> slots;
  factory OrderSlots.fromJson(Map<String, dynamic> j) => OrderSlots(
    date: j['date'] as String? ?? '',
    asapAvailable: j['asapAvailable'] != false,
    slots: (j['slots'] as List<dynamic>? ?? [])
        .map((e) => OrderSlot.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}

/// Live tracking payload (c11): master location + ETA while on the way.
class TrackInfo {
  const TrackInfo({required this.status, this.lat, this.lng, this.etaMinutes});
  final String status;
  final double? lat;
  final double? lng;
  final int? etaMinutes;
  factory TrackInfo.fromJson(Map<String, dynamic> j) {
    final loc = j['masterLocation'] as Map<String, dynamic>?;
    return TrackInfo(
      status: j['status'] as String? ?? '',
      lat: _dbl(loc?['latitude'] ?? loc?['lat']),
      lng: _dbl(loc?['longitude'] ?? loc?['lng']),
      etaMinutes: _intN(j['etaMinutes']),
    );
  }
}

/// A staged photo returned by the upload endpoint (before the order is created).
class UploadedPhoto {
  const UploadedPhoto({required this.fileKey, this.mimeType, this.sizeBytes});
  final String fileKey;
  final String? mimeType;
  final int? sizeBytes;
  factory UploadedPhoto.fromJson(Map<String, dynamic> j) => UploadedPhoto(
    fileKey: j['fileKey'] as String? ?? '',
    mimeType: j['mimeType'] as String?,
    sizeBytes: _intN(j['sizeBytes']),
  );
}
