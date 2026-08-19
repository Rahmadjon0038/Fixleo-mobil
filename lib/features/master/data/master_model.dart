import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/features/master/data/localized_rejection_reasons.dart';

/// Account status of a master.
enum MasterStatus {
  unverified,
  active,
  blocked;

  static MasterStatus fromString(String? v) => switch (v) {
    'active' => MasterStatus.active,
    'blocked' => MasterStatus.blocked,
    _ => MasterStatus.unverified,
  };
}

/// KYC moderation status of a master.
enum VerificationStatus {
  notSubmitted,
  pending,
  approved,
  rejected;

  static VerificationStatus fromString(String? v) => switch (v) {
    'pending' => VerificationStatus.pending,
    'approved' => VerificationStatus.approved,
    'rejected' => VerificationStatus.rejected,
    _ => VerificationStatus.notSubmitted,
  };
}

/// A master (usta) profile — `MasterResponseDto` (see `api/MasterRegister.md`).
class Master {
  const Master({
    required this.id,
    required this.phone,
    required this.status,
    required this.verificationStatus,
    this.rejectionReason,
    this.rejectionReasons = const LocalizedRejectionReasons(),
    this.name,
    this.city,
    this.experienceYears,
    this.bio,
    this.avatarUrl,
    this.latitude,
    this.longitude,
    this.workRadiusKm,
    this.categories = const [],
    this.createdAt,
    this.updatedAt,
    this.isDemo = false,
  });

  /// Public id, e.g. `#M-00000000001`.
  final String id;
  final String phone;
  final MasterStatus status;
  final VerificationStatus verificationStatus;
  final String? rejectionReason;
  final LocalizedRejectionReasons rejectionReasons;
  final String? name;
  final String? city;
  final int? experienceYears;
  final String? bio;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;
  final int? workRadiusKm;
  final List<Category> categories;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// App-store/Play-Market review account — the app must hide all money UI.
  final bool isDemo;

  factory Master.fromJson(Map<String, dynamic> json) {
    final rejectionReason = json['rejectionReason'] as String?;
    return Master(
      id: json['id'].toString(),
      phone: json['phone'] as String,
      status: MasterStatus.fromString(json['status'] as String?),
      verificationStatus: VerificationStatus.fromString(
        json['verificationStatus'] as String?,
      ),
      rejectionReason: rejectionReason,
      rejectionReasons: LocalizedRejectionReasons.fromJson(
        json['rejectionReasons'],
        legacy: rejectionReason,
      ),
      name: json['name'] as String?,
      city: json['city'] as String?,
      experienceYears: (json['experienceYears'] as num?)?.toInt(),
      bio: json['bio'] as String?,
      avatarUrl: ApiConfig.resolveMediaUrl(json['avatarUrl']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      workRadiusKm: (json['workRadiusKm'] as num?)?.toInt(),
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      isDemo: json['isDemo'] as bool? ?? false,
    );
  }
}
