/// One entry in the admin audit log (see `api/AdminAuditLog.md`).
///
/// Records a single mutating admin action (POST / PATCH / PUT / DELETE):
/// who did it, what path, and the resulting status.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.method,
    required this.path,
    this.adminId,
    this.adminEmail,
    this.statusCode,
    this.requestId,
    this.createdAt,
  });

  final int id;
  final String method;
  final String path;
  final int? adminId;
  final String? adminEmail;
  final int? statusCode;
  final String? requestId;
  final DateTime? createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: (json['id'] as num).toInt(),
        method: json['method'] as String,
        path: json['path'] as String,
        adminId: (json['adminId'] as num?)?.toInt(),
        adminEmail: json['adminEmail'] as String?,
        statusCode: (json['statusCode'] as num?)?.toInt(),
        requestId: json['requestId'] as String?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}
