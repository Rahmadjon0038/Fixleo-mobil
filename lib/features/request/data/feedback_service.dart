import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_config.dart';

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _intN(dynamic v) => (v as num?)?.toInt();
double? _dbl(dynamic v) => (v as num?)?.toDouble();

/// Reviews + complaints a client leaves on a completed order
/// (see docs/v3/ReviewsComplaints.md).
class FeedbackService {
  FeedbackService({ApiClient? client}) : _client = client ?? ApiClient.instance;
  final ApiClient _client;

  /// `POST /clients/me/orders/:id/review`
  Future<void> review(
    int orderId, {
    required int rating,
    List<String> tags = const [],
    String? text,
  }) => _client.post(
    '/clients/me/orders/$orderId/review',
    body: {
      'rating': rating,
      'tags': tags,
      if (text != null && text.isNotEmpty) 'text': text,
    },
  );

  /// `POST /clients/me/orders/:id/complaint`
  Future<void> complaint(
    int orderId, {
    required String reason, // master_late | work_quality | overpriced | other
    required String description,
  }) => _client.post(
    '/clients/me/orders/$orderId/complaint',
    body: {'reason': reason, 'description': description},
  );
}

/// Public master profile (c07) — auth not required, no order needed.
class MasterPublicProfile {
  const MasterPublicProfile({
    required this.name,
    this.avatarUrl,
    this.bio,
    this.city,
    this.experienceYears,
    this.categories = const [],
    this.ratingAvg,
    this.ratingCount = 0,
    this.ratingHist = const {},
    this.completedOrders = 0,
    this.completionRate,
    this.isTopMaster = false,
    this.portfolio = const [],
    this.recentReviews = const [],
  });

  final String? name;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final int? experienceYears;
  final List<String> categories;
  final double? ratingAvg;
  final int ratingCount;
  final Map<int, int> ratingHist;
  final int completedOrders;
  final int? completionRate;
  final bool isTopMaster;
  final List<String> portfolio;
  final List<PublicReview> recentReviews;

  factory MasterPublicProfile.fromJson(Map<String, dynamic> j) =>
      MasterPublicProfile(
        name: j['name'] as String?,
        avatarUrl: ApiConfig.resolveMediaUrl(j['avatarUrl']),
        bio: j['bio'] as String?,
        city: j['city'] as String?,
        experienceYears: _intN(j['experienceYears']),
        categories: (j['categories'] as List<dynamic>? ?? [])
            .map((e) => (e as Map<String, dynamic>)['name'] as String? ?? '')
            .toList(growable: false),
        ratingAvg: _dbl(j['ratingAvg']),
        ratingCount: _int(j['ratingCount']),
        ratingHist: {
          for (final entry
              in (j['ratingHist'] as Map<String, dynamic>? ?? const {}).entries)
            if (int.tryParse(entry.key) != null)
              int.parse(entry.key): _int(entry.value),
        },
        completedOrders: _int(j['completedOrders']),
        completionRate: _intN(j['completionRate']),
        isTopMaster: j['isTopMaster'] == true,
        portfolio: (j['portfolio'] as List<dynamic>? ?? [])
            .map((e) => (e as Map<String, dynamic>)['url'] as String? ?? '')
            .toList(growable: false),
        recentReviews: (j['recentReviews'] as List<dynamic>? ?? [])
            .map((e) => PublicReview.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class PublicReview {
  const PublicReview({
    required this.id,
    required this.rating,
    this.text,
    this.clientName,
  });
  final int id;
  final int rating;
  final String? text;
  final String? clientName;
  factory PublicReview.fromJson(Map<String, dynamic> j) => PublicReview(
    id: _int(j['id']),
    rating: _int(j['rating']),
    text: j['text'] as String?,
    clientName: j['clientName'] as String?,
  );
}

class MasterPublicService {
  MasterPublicService({ApiClient? client})
    : _client = client ?? ApiClient.instance;
  final ApiClient _client;

  Future<MasterPublicProfile> profile(int masterId) async {
    final data = await _client.get('/masters/$masterId/public');
    return MasterPublicProfile.fromJson(data as Map<String, dynamic>);
  }
}
