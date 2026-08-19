import 'package:flutter/material.dart';

import 'package:fixleo/app/widgets/glass/glass_button.dart';

/// Full-width blue action button used at the bottom of screens. Renders as
/// tinted "Liquid Glass" — see [GlassButton] — instead of a flat fill.
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
    return GlassButton(label: label, onPressed: onPressed, icon: icon);
  }
}
