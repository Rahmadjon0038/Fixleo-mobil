import 'package:flutter/material.dart';

import 'glass_container.dart';

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
    final glass = GlassContainer(
      borderRadius: size / 2,
      width: size,
      height: size,
      alignment: Alignment.center,
      child: child,
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              glass,
              if (badgeCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
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
          ),
        ),
      ),
    );
  }
}
