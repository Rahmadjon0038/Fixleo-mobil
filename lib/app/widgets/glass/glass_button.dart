import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'glass_platform.dart';
import 'glass_tap_target.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart' as native;

/// Visual weight of a [GlassButton].
enum GlassButtonVariant {
  /// Brand-blue tinted glass — the main call-to-action style (replaces the
  /// old flat-fill [PrimaryButton]).
  primary,

  /// Danger/destructive action — red tinted glass.
  danger,

  /// Neutral white glass — secondary actions that shouldn't compete with a
  /// primary button on the same screen.
  secondary,
}

/// Full-width (by default) pill button rendered as tinted "Liquid Glass"
/// instead of a flat fill: a translucent gradient + blur + bright edge
/// highlight, tinted by [variant]. Same call signature as the old
/// `PrimaryButton` so existing call sites don't need to change shape.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GlassButtonVariant.primary,
    this.height = 56,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassButtonVariant variant;
  final double height;
  final bool expand;

  static const _blue = Color(0xFF0079EB);
  static const _navy = Color(0xFF1C274C);
  static const _danger = Color(0xFFEF4444);

  Color get _tint {
    switch (variant) {
      case GlassButtonVariant.primary:
        return _blue;
      case GlassButtonVariant.danger:
        return _danger;
      case GlassButtonVariant.secondary:
        return Colors.white;
    }
  }

  Color get _foreground {
    return variant == GlassButtonVariant.secondary ? _navy : Colors.white;
  }

  bool get _disabled => onPressed == null;

  @override
  Widget build(BuildContext context) {
    final tint = _disabled ? _tint.withValues(alpha: 0.5) : _tint;
    final radius = height / 2;

    final text = Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _foreground.withValues(alpha: _disabled ? 0.7 : 1),
      ),
    );

    final body = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: _foreground.withValues(alpha: _disabled ? 0.7 : 1),
              ),
              const SizedBox(width: 8),
              text,
            ],
          );

    if (usesNativeLiquidGlass(context)) {
      return GlassTapTarget(
        label: label,
        onTap: onPressed,
        child: native.LiquidGlassContainer(
          shape: const native.LiquidGlassShape.capsule(),
          tint: variant == GlassButtonVariant.secondary ? null : tint,
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(child: body),
        ),
      );
    }
    final glass = GlassContainer(
      tint: tint,
      tintOpacityTop: variant == GlassButtonVariant.secondary ? 0.75 : 0.90,
      tintOpacityBottom: variant == GlassButtonVariant.secondary ? 0.55 : 0.74,
      borderOpacity: variant == GlassButtonVariant.secondary ? 0.8 : 0.5,
      borderRadius: radius,
      height: height,
      shadow: !_disabled,
      shadowColor: tint,
      alignment: Alignment.center,
      // Without this, a non-expanded (expand: false) button has no width
      // constraint of its own, so it shrinks exactly to the text — the pill
      // edges then touch the label with no breathing room either side.
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: body,
    );

    final button = Semantics(
      button: true,
      enabled: !_disabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ExcludeSemantics(child: glass),
      ),
    );

    return expand
        ? SizedBox(width: double.infinity, height: height, child: button)
        : SizedBox(height: height, child: button);
  }
}
