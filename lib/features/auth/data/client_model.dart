import 'package:fixleo/core/network/api_config.dart';

/// A client (end-user) account (see `api/LoginOrRegisterClient.md`).
class Client {
  const Client({
    required this.id,
    required this.phone,
    required this.status,
    this.name,
    this.birthDate,
    this.gender,
    this.avatarUrl,
    this.blockReason,
    this.createdAt,
    this.updatedAt,
  });

  /// Public id, e.g. `#U-00000000001`.
  final String id;
  final String phone;

  /// `unverified` | `active` | `blocked`.
  final String status;
  final String? name;
  final DateTime? birthDate;
  final String? gender;
  final String? avatarUrl;
  final String? blockReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';
  bool get isBlocked => status == 'blocked';

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id'].toString(),
    phone: json['phone'] as String,
    status: json['status'] as String? ?? 'unverified',
    name: json['name'] as String?,
    birthDate: DateTime.tryParse(json['birthDate']?.toString() ?? ''),
    gender: json['gender'] as String?,
    avatarUrl: ApiConfig.resolveMediaUrl(json['avatarUrl']),
    blockReason: json['blockReason'] as String?,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
  );
}
