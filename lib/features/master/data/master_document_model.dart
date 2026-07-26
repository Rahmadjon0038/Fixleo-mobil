/// The KYC document types a master must upload before verification.
enum MasterDocumentType {
  passportFront('passport_front'),
  passportBack('passport_back'),
  selfieWithPassport('selfie_with_passport');

  const MasterDocumentType(this.apiValue);

  /// Value sent as the multipart `type` field.
  final String apiValue;

  static MasterDocumentType? fromApi(String? v) {
    for (final t in MasterDocumentType.values) {
      if (t.apiValue == v) return t;
    }
    return null;
  }
}

/// An uploaded KYC document — `DocumentDto` (see `api/MasterRegister.md`).
///
/// `url` is a short-lived (~5 min) presigned link; re-fetch the list when it
/// expires.
class MasterDocument {
  const MasterDocument({
    required this.id,
    required this.type,
    required this.mimeType,
    required this.sizeBytes,
    required this.url,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final MasterDocumentType? type;
  final String mimeType;
  final int sizeBytes;
  final String url;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MasterDocument.fromJson(Map<String, dynamic> json) => MasterDocument(
    id: (json['id'] as num).toInt(),
    type: MasterDocumentType.fromApi(json['type'] as String?),
    mimeType: json['mimeType'] as String? ?? '',
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
  );
}
