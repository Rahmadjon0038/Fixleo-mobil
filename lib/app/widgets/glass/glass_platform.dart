import 'dart:ui';
import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => usesGlassMaterial(context)
      ? BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        )
      : child;
}
