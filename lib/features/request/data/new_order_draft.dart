/// Mutable draft carried through the "new request" wizard (new_request →
/// address → time → review). The final screen submits it via
/// [OrderService.create]. One instance flows by reference through the screens.
class NewOrderDraft {
  NewOrderDraft({this.categoryId, this.categoryName});

  int? categoryId;
  String? categoryName;

  String description = '';
  List<String> photoKeys = [];

  double? latitude;
  double? longitude;
  String addressText = '';
  String? district;
  String? addressDetails;

  /// asap | today | scheduled
  String timing = 'asap';
  String? scheduledDate; // YYYY-MM-DD
  String? slot; // s10_12 | s12_15 | s15_18 | s18_21
  int? budgetMax;

  bool get hasLocation => latitude != null && longitude != null;
}
