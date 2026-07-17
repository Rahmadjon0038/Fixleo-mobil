/// An admin account (see `api/AdminLogin.md`).
class Admin {
  const Admin({
    required this.id,
    required this.email,
    required this.role,
    this.fullname,
    this.createdAt,
    this.updatedAt,
  });

  /// Public id, e.g. `#Admin-1`.
  final String id;
  final String email;

  /// `admin` | `superadmin`.
  final String role;
  final String? fullname;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSuperadmin => role == 'superadmin';

  factory Admin.fromJson(Map<String, dynamic> json) => Admin(
        id: json['id'].toString(),
        email: json['email'] as String,
        role: json['role'] as String? ?? 'admin',
        fullname: json['fullname'] as String?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}
