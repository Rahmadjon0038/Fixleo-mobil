import 'package:fixleo/features/categories/data/category_model.dart';

class MasterServicePrice {
  const MasterServicePrice({
    required this.category,
    this.price,
    this.locked = false,
    this.openOrderCount = 0,
  });
  final Category category;
  final int? price;
  final bool locked;
  final int openOrderCount;

  factory MasterServicePrice.fromJson(Map<String, dynamic> json) =>
      MasterServicePrice(
        category: Category.fromJson({...json, 'id': json['categoryId']}),
        price: (json['price'] as num?)?.toInt(),
        locked: json['locked'] == true,
        openOrderCount: (json['openOrderCount'] as num?)?.toInt() ?? 0,
      );
}
