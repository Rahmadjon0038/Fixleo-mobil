import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart' as native;

/// Runtime platform, not a Theme override: never creates UIKit views on Android
/// or in host-side widget tests. iOS <26 is handled by the native system fallback.
bool usesNativeLiquidGlass(BuildContext context) =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS &&
    usesGlassMaterial(context);

/// Neutral legacy fills become clear glass; brand/danger/selection colors keep
/// their meaning without painting an opaque veil over the native refraction.
Color? liquidSurfaceTint(Color? color) {
  if (color == null || color.a == 0) return null;
  if (color.r > .88 && color.g > .88 && color.b > .88) return null;
  return color.withValues(alpha: color.a.clamp(0, .65));
}

class NativeLiquidSurface extends StatelessWidget {
  const NativeLiquidSurface({super.key, this.radius = 24, this.tint});
  final double radius;
  final Color? tint;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: native.LiquidGlassContainer(
      shape: native.LiquidGlassShape.roundedRectangle(radius),
      tint: tint,
      child: const SizedBox.expand(),
    ),
  );
}

/// Apple chrome uses frosted glass. Android gets a solid, inexpensive surface.
/// High contrast prefers the opaque alternative on every platform.
bool usesGlassMaterial(BuildContext context) =>
    !MediaQuery.highContrastOf(context) &&
    (Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS);

class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child, this.sigma = 24});
  final Widget child;
  final double sigma;

  @override
  Widget build(BuildContext context) => usesNativeLiquidGlass(context)
      ? Stack(
          fit: StackFit.passthrough,
          children: [
            const Positioned.fill(child: NativeLiquidSurface(radius: 28)),
            child,
          ],
        )
      : usesGlassMaterial(context)
      ? BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        )
      : child;
}
