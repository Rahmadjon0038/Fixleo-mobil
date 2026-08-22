import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/features/categories/data/category_model.dart';

/// Network-backed catalog artwork with a deterministic icon fallback.
class CategoryImage extends StatelessWidget {
  const CategoryImage({
    required this.category,
    super.key,
    this.borderRadius = 18,
    this.fit = BoxFit.cover,
  });

  final Category category;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageUrl == null
          ? _fallback()
          : Image.network(
              imageUrl,
              fit: fit,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => _fallback(),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            ),
    );
  }

  Widget _fallback() => Container(
    color: const Color(0xFFEAF3FE),
    alignment: Alignment.center,
    child: Icon(
      categoryFallbackIcon(category.name),
      color: AppColors.blue,
      size: 34,
    ),
  );
}

IconData categoryFallbackIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('сантех') ||
      value.contains('santex') ||
      value.contains('plumb')) {
    return Icons.water_drop_outlined;
  }
  if (value.contains('электр') ||
      value.contains('elektr') ||
      value.contains('electric')) {
    return Icons.bolt_outlined;
  }
  if (value.contains('убор') ||
      value.contains('tozal') ||
      value.contains('clean')) {
    return Icons.cleaning_services_outlined;
  }
  if (value.contains('техник') ||
      value.contains('texnik') ||
      value.contains('appliance')) {
    return Icons.kitchen_outlined;
  }
  if (value.contains('крас') ||
      value.contains('bo‘y') ||
      value.contains("bo'y") ||
      value.contains('paint')) {
    return Icons.format_paint_outlined;
  }
  if (value.contains('мебел') ||
      value.contains('yig‘') ||
      value.contains("yig'") ||
      value.contains('furniture')) {
    return Icons.chair_alt_outlined;
  }
  if (value.contains('garden') ||
      value.contains('bog‘') ||
      value.contains('сад')) {
    return Icons.yard_outlined;
  }
  return Icons.handyman_outlined;
}
