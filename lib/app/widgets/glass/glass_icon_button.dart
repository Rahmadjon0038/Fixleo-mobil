import 'package:flutter/material.dart';

import 'glass_container.dart';
import 'glass_platform.dart';
import 'glass_tap_target.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart' as native;

/// Round frosted glass icon button — the shared shape behind the back
/// button, header notification/profile buttons, and the various private
/// `_CircleIconButton`/`_GlassButton` duplicates across screens.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.child,
    this.onTap,
    this.size = 44,
    this.badgeCount = 0,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final int badgeCount;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isNative = usesNativeLiquidGlass(context);
    final glass = isNative
        ? native.LiquidGlassContainer(
            shape: const native.LiquidGlassShape.capsule(),
            width: size,
            height: size,
            child: Center(child: child),
          )
        : GlassContainer(
            borderRadius: size / 2,
            width: size,
            height: size,
            alignment: Alignment.center,
            child: child,
          );

    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        glass,
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
    if (isNative) {
      return GlassTapTarget(onTap: onTap, label: semanticLabel, child: content);
    }
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(child: content),
      ),
    );
  }
}
