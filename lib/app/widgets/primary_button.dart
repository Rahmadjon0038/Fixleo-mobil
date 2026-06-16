import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';

/// Full-width blue action button used at the bottom of screens.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: icon == null
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 8),
                  text,
                ],
              ),
      ),
    );
  }
}
