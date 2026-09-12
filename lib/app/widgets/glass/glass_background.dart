import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_platform.dart';

/// Soft ambient wash painted behind every screen so glass panels have
/// something with visible depth to blur/refract — plain flat backgrounds
/// make `BackdropFilter` glass read as flat translucent white with no
/// "liquid" quality. A handful of large, very low-alpha brand-color blobs
/// on the base surface color give just enough variation.
///
/// Cheap by construction: it's one gradient paint per blob, not a
/// `BackdropFilter` — the expensive blur lives only in the glass panels
/// drawn on top of this, never here.
class GlassBackground extends StatelessWidget {
  const GlassBackground({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFF4F5F7),
  });

  final Widget child;
  final Color baseColor;

  static const _blue = Color(0xFF0079EB);
  static const _navy = Color(0xFF1C274C);

  @override
  Widget build(BuildContext context) {
    if (!usesGlassMaterial(context)) {
      return ColoredBox(color: baseColor, child: child);
    }
    final background = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: baseColor),
        Positioned(
          top: -90,
          right: -70,
          child: _blob(360, _blue.withValues(alpha: 0.22)),
        ),
        Positioned(
          top: 260,
          left: -110,
          child: _blob(320, _navy.withValues(alpha: 0.10)),
        ),
        Positioned(
          bottom: -120,
          right: -60,
          child: _blob(380, _blue.withValues(alpha: 0.17)),
        ),
        child,
      ],
    );
    // UIKit glass views must not leave white status text over a light screen.
    return usesNativeLiquidGlass(context)
        ? AnnotatedRegion<SystemUiOverlayStyle>(
            value: baseColor.computeLuminance() > .5
                ? SystemUiOverlayStyle.dark
                : SystemUiOverlayStyle.light,
            child: background,
          )
        : background;
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
