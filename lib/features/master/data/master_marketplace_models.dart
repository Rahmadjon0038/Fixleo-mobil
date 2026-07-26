// Master-side marketplace models — field names mirror the backend DTOs
// (see docs/v3/Orders.md, Payments.md).

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _intN(dynamic v) => (v as num?)?.toInt();
double _dbl(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dblN(dynamic v) => (v as num?)?.toDouble();

/// A card in the master's "Заявки рядом" feed.
class FeedItem {
  const FeedItem({
    required this.id,
    required this.categoryName,
    required this.description,
    this.district,
    this.distanceKm = 0,
    this.timing = '',
    this.slotLabel,
    this.scheduledDate,
    this.budgetMax,
    this.createdAt,
  });

  final int id;
  final String categoryName;
  final String description;
  final String? district;
  final double distanceKm;
  final String timing;
  final String? slotLabel;
  final String? scheduledDate;
  final int? budgetMax;
  final DateTime? createdAt;

  factory FeedItem.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    return FeedItem(
      id: _int(j['id']),
      categoryName: cat?['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      district: j['district'] as String?,
      distanceKm: _dbl(j['distanceKm']),
      timing: j['timing'] as String? ?? '',
      slotLabel: j['slotLabel'] as String?,
      scheduledDate: j['scheduledDate'] as String?,
      budgetMax: _intN(j['budgetMax']),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
    );
  }
}

class FeedDetail {
  const FeedDetail({
    required this.id,
    required this.categoryName,
    required this.description,
    required this.addressText,
    this.district,
    this.distanceKm = 0,
    this.timing = '',
    this.slotLabel,
    this.scheduledDate,
    this.budgetMax,
    this.clientName,
    this.photos = const [],
    this.myOfferId,
    this.myOfferStatus,
    this.createdAt,
  });

  final int id;
  final String categoryName;
  final String description;
  final String addressText;
  final String? district;
  final double distanceKm;
  final String timing;
  final String? slotLabel;
  final String? scheduledDate;
  final int? budgetMax;
  final String? clientName;
  final List<String> photos;
  final int? myOfferId;
  final String? myOfferStatus;
  final DateTime? createdAt;

  bool get hasOffer => myOfferId != null;

  factory FeedDetail.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    final myOffer = j['myOffer'] as Map<String, dynamic>?;
    return FeedDetail(
      id: _int(j['id']),
      categoryName: cat?['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      addressText: j['addressText'] as String? ?? '',
      district: j['district'] as String?,
      distanceKm: _dbl(j['distanceKm']),
      timing: j['timing'] as String? ?? '',
      slotLabel: j['slotLabel'] as String?,
      scheduledDate: j['scheduledDate'] as String?,
      budgetMax: _intN(j['budgetMax']),
      clientName: j['clientName'] as String?,
      photos: (j['photos'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['url'] as String? ?? '')
          .toList(growable: false),
      myOfferId: _intN(myOffer?['id']),
      myOfferStatus: myOffer?['status'] as String?,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
    );
  }
}

/// My offer row (m — "Отклики" tab).
class MyOffer {
  const MyOffer({
    required this.id,
    required this.status,
    this.price,
    required this.orderId,
    required this.orderTitle,
    required this.orderStatus,
  });
  final int id;
  final String status;
  final int? price;
  final int orderId;
  final String orderTitle;
  final String orderStatus;
  factory MyOffer.fromJson(Map<String, dynamic> j) {
    final o = j['order'] as Map<String, dynamic>? ?? const {};
    return MyOffer(
      id: _int(j['id']),
      status: j['status'] as String? ?? '',
      price: _intN(j['price']),
      orderId: _int(o['id']),
      orderTitle: o['title'] as String? ?? '',
      orderStatus: o['status'] as String? ?? '',
    );
  }
}

/// A job in the master's "Работа" list.
class MasterOrder {
  const MasterOrder({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.addressText,
    this.addressDetails,
    this.price,
    this.createdAt,
  });
  final int id;
  final String title;
  final String description;
  final String status;
  final String addressText;
  final String? addressDetails;
  final int? price;
  final DateTime? createdAt;
  factory MasterOrder.fromJson(Map<String, dynamic> j) => MasterOrder(
    id: _int(j['id']),
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    status: j['status'] as String? ?? '',
    addressText: j['addressText'] as String? ?? '',
    addressDetails: j['addressDetails'] as String?,
    price: _intN(j['price']),
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
  );
}

class MasterOrderDetail {
  const MasterOrderDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.addressText,
    this.addressDetails,
    this.price,
    this.priceType,
    this.timing = '',
    this.slotLabel,
    this.scheduledDate,
    this.clientName,
    this.clientPhone,
    this.conversationId,
    this.nextStatus,
    this.canComplete = false,
    this.canCancel = false,
    this.timeline = const [],
  });

  final int id;
  final String title;
  final String description;
  final String status;
  final String addressText;
  final String? addressDetails;
  final int? price;
  final String? priceType;
  final String timing;
  final String? slotLabel;
  final String? scheduledDate;
  final String? clientName;
  final String? clientPhone;
  final int? conversationId;
  final String? nextStatus;
  final bool canComplete;
  final bool canCancel;
  final List<MapEntry<String, DateTime?>> timeline;

  factory MasterOrderDetail.fromJson(Map<String, dynamic> j) {
    final client = j['client'] as Map<String, dynamic>?;
    final cap = j['capabilities'] as Map<String, dynamic>?;
    return MasterOrderDetail(
      id: _int(j['id']),
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      status: j['status'] as String? ?? '',
      addressText: j['addressText'] as String? ?? '',
      addressDetails: j['addressDetails'] as String?,
      price: _intN(j['finalAmount']) ?? _intN(j['agreedPrice']),
      priceType: j['priceType'] as String?,
      timing: j['timing'] as String? ?? '',
      slotLabel: j['slotLabel'] as String?,
      scheduledDate: j['scheduledDate'] as String?,
      clientName: client?['name'] as String?,
      clientPhone: client?['phone'] as String?,
      conversationId: _intN(j['conversationId']),
      nextStatus: cap?['nextStatus'] as String?,
      canComplete: cap?['canComplete'] == true,
      canCancel: cap?['canCancel'] == true,
      timeline: (j['timeline'] as List<dynamic>? ?? [])
          .map(
            (e) => MapEntry(
              (e as Map<String, dynamic>)['to'] as String? ?? '',
              DateTime.tryParse(e['at']?.toString() ?? ''),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// A review left by a real client for the authenticated master.
class MasterReview {
  const MasterReview({
    required this.id,
    required this.rating,
    this.tags = const [],
    this.text,
    this.clientName,
    this.createdAt,
  });

  final int id;
  final int rating;
  final List<String> tags;
  final String? text;
  final String? clientName;
  final DateTime? createdAt;

  factory MasterReview.fromJson(Map<String, dynamic> j) => MasterReview(
    id: _int(j['id']),
    rating: _int(j['rating']),
    tags: (j['tags'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(growable: false),
    text: j['text'] as String?,
    clientName: j['clientName'] as String?,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
  );
}

/// Paginated review response plus the backend-calculated rating aggregate.
class MasterReviews {
  const MasterReviews({
    this.items = const [],
    this.ratingAvg,
    this.ratingCount = 0,
    this.ratingHist = const {},
  });

  final List<MasterReview> items;
  final double? ratingAvg;
  final int ratingCount;
  final Map<int, int> ratingHist;

  factory MasterReviews.fromJson(Map<String, dynamic> j) {
    final aggregate = j['aggregate'] as Map<String, dynamic>? ?? const {};
    final rawHist =
        aggregate['ratingHist'] as Map<String, dynamic>? ?? const {};
    return MasterReviews(
      items: (j['items'] as List<dynamic>? ?? [])
          .map((e) => MasterReview.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      ratingAvg: _dblN(aggregate['ratingAvg']),
      ratingCount: _int(aggregate['ratingCount']),
      ratingHist: {
        for (final entry in rawHist.entries)
          if (int.tryParse(entry.key) != null)
            int.parse(entry.key): _int(entry.value),
      },
    );
  }
}

/// Master wallet summary (m32).
class MasterWallet {
  const MasterWallet({
    required this.balance,
    this.monthEarned = 0,
    this.completedOrders = 0,
    this.ratingAvg,
    this.withdrawInstantFeePct = 0,
    this.withdrawMin = 0,
  });
  final int balance;
  final int monthEarned;
  final int completedOrders;
  final double? ratingAvg;
  final double withdrawInstantFeePct;
  final int withdrawMin;
  factory MasterWallet.fromJson(Map<String, dynamic> j) => MasterWallet(
    balance: _int(j['balance']),
    monthEarned: _int(j['monthEarned']),
    completedOrders: _int(j['completedOrders']),
    ratingAvg: _dblN(j['ratingAvg']),
    withdrawInstantFeePct: _dbl(j['withdrawInstantFeePct']),
    withdrawMin: _int(j['withdrawMin']),
  );
}

class WalletTx {
  const WalletTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.createdAt,
  });
  final int id;
  final String type;
  final int amount;
  final int balanceAfter;
  final DateTime? createdAt;
  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
    id: _int(j['id']),
    type: j['type'] as String? ?? '',
    amount: _int(j['amount']),
    balanceAfter: _int(j['balanceAfter']),
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
  );
}
