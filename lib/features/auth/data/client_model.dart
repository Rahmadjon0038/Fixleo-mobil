/// A client (end-user) account (see `api/LoginOrRegisterClient.md`).
class Client {
  const Client({
    required this.id,
    required this.phone,
    required this.status,
    this.name,
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
        blockReason: json['blockReason'] as String?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}
