import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/master/data/master_document_model.dart';

/// Compact master info shown inside a verification queue row.
class VerificationMaster {
  const VerificationMaster({
    required this.id,
    this.name,
    this.phone,
    this.city,
    this.categories = const [],
  });

  final String id;
  final String? name;
  final String? phone;
  final String? city;
  final List<Category> categories;

  factory VerificationMaster.fromJson(Map<String, dynamic> json) =>
      VerificationMaster(
        id: json['id'].toString(),
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        city: json['city'] as String?,
        categories: (json['categories'] as List<dynamic>? ?? const [])
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// Moderator checklist on a verification.
class VerificationChecklist {
  const VerificationChecklist({
    this.documentReadable,
    this.photoMatchesSelfie,
    this.dataMatchesForm,
  });

  final bool? documentReadable;
  final bool? photoMatchesSelfie;
  final bool? dataMatchesForm;

  factory VerificationChecklist.fromJson(Map<String, dynamic> json) =>
      VerificationChecklist(
        documentReadable: json['documentReadable'] as bool?,
        photoMatchesSelfie: json['photoMatchesSelfie'] as bool?,
        dataMatchesForm: json['dataMatchesForm'] as bool?,
      );
}

/// A row in the KYC moderation queue (`GET /admin/verifications`).
class VerificationListItem {
  const VerificationListItem({
    required this.id,
    required this.status,
    required this.master,
    this.submittedAt,
  });

  /// Public id, e.g. `#V-88`.
  final String id;

  /// `pending` | `approved` | `rejected`.
  final String status;
  final VerificationMaster master;
  final DateTime? submittedAt;

  factory VerificationListItem.fromJson(Map<String, dynamic> json) =>
      VerificationListItem(
        id: json['id'].toString(),
        status: json['status'] as String? ?? 'pending',
        master:
            VerificationMaster.fromJson(json['master'] as Map<String, dynamic>),
        submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      );
}

/// Full verification detail (`GET /admin/verifications/:id`).
class VerificationDetail {
  const VerificationDetail({
    required this.id,
    required this.status,
    required this.master,
    required this.documents,
    required this.checklist,
    this.submittedAt,
    this.rejectionReason,
    this.decidedAt,
  });

  final String id;
  final String status;
  final VerificationMaster master;
  final List<MasterDocument> documents;
  final VerificationChecklist checklist;
  final DateTime? submittedAt;
  final String? rejectionReason;
  final DateTime? decidedAt;

  factory VerificationDetail.fromJson(Map<String, dynamic> json) =>
      VerificationDetail(
        id: json['id'].toString(),
        status: json['status'] as String? ?? 'pending',
        master:
            VerificationMaster.fromJson(json['master'] as Map<String, dynamic>),
        documents: (json['documents'] as List<dynamic>? ?? const [])
            .map((e) => MasterDocument.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        checklist: VerificationChecklist.fromJson(
            (json['checklist'] as Map<String, dynamic>?) ?? const {}),
        submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
        rejectionReason: json['rejectionReason'] as String?,
        decidedAt: DateTime.tryParse(json['decidedAt']?.toString() ?? ''),
      );
}
