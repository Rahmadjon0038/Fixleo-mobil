/// Account status for a client (end-user). See `api/AdminClients.md`.
enum ClientStatus {
  unverified,
  active,
  blocked;

  static ClientStatus fromString(String? value) => switch (value) {
        'active' => ClientStatus.active,
        'blocked' => ClientStatus.blocked,
        _ => ClientStatus.unverified,
      };

  String get apiValue => name;
}

/// A client (end-user) account as returned by the admin endpoints.
///
/// `id` is the public format (`#U-00000000003`); admin mutation routes take the
/// numeric DB id in the path instead (see [AdminClientService]).
class AdminClient {
  const AdminClient({
    required this.id,
    required this.phone,
    required this.status,
    this.name,
    this.blockReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String phone;
  final ClientStatus status;
  final String? name;
  final String? blockReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminClient.fromJson(Map<String, dynamic> json) => AdminClient(
        id: json['id'].toString(),
        phone: json['phone'] as String,
        status: ClientStatus.fromString(json['status'] as String?),
        name: json['name'] as String?,
        blockReason: json['blockReason'] as String?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}
