import 'dart:ui';

import 'package:flutter/material.dart';
import 'glass_platform.dart';

/// Core "Liquid Glass" surface — a translucent, blurred panel with a bright
/// specular edge highlight, matching iOS's frosted-glass material.
///
/// Structure follows the pattern already used by [LiquidGlassNavBar] and the
/// [BrandedScaffold] back button: the blur + tint fill sits in a background
/// layer with NO interactive children (BackdropFilter under a hit-testable
/// widget trips a macOS mouse_tracker bug), while [child] is painted in a
/// separate layer on top, free to hold buttons/gestures.
///
/// Use the default constructor for chrome that appears once per screen
/// (cards, headers, hero banners, buttons, sheets). Use [GlassContainer.lite]
/// for anything repeated many times in a scrolling list (chat bubbles, order
/// rows, notification rows) — it keeps the same tinted/bordered look without
/// the expensive `BackdropFilter`, which janks when stacked dozens of times.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tint = Colors.white,
    this.tintOpacityTop = 0.64,
    this.tintOpacityBottom = 0.34,
    this.borderOpacity = 0.75,
    this.borderWidth = 1,
    this.shadow = true,
    this.shadowColor,
    this.alignment,
  }) : blur = true,
       blurSigma = 20;

  const GlassContainer.lite({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tint = Colors.white,
    this.tintOpacityTop = 0.76,
    this.tintOpacityBottom = 0.54,
    this.borderOpacity = 0.75,
    this.borderWidth = 1,
    // Off by default: `.lite` items are almost always packed edge-to-edge
    // (chip rows, grids) or stacked with modest gaps (list rows), and the
    // singleton-card drop shadow smears across neighbors into one glowing
    // blob instead of reading as separate items. Pass `shadow: true`
    // explicitly for the rare `.lite` item that truly floats alone.
    this.shadow = false,
    this.shadowColor,
    this.alignment,
  }) : blur = false,
       blurSigma = 0;

  const GlassContainer._raw({
    required this.child,
    required this.blur,
    required this.blurSigma,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tint = Colors.white,
    this.tintOpacityTop = 0.72,
    this.tintOpacityBottom = 0.50,
    this.borderOpacity = 0.75,
    this.shadow = true,
    this.alignment,
    super.key,
  }) : borderWidth = 1,
       shadowColor = null;

  /// Dark, higher-contrast glass for hero surfaces over the brand navy
  /// (search hero, dark banners) — same material, tinted dark instead of
  /// white so light text on top stays legible.
  factory GlassContainer.dark({
    Key? key,
    required Widget child,
    double borderRadius = 24,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    bool shadow = true,
    AlignmentGeometry? alignment,
  }) {
    return GlassContainer._raw(
      key: key,
      blur: true,
      blurSigma: 24,
      tint: const Color(0xFF121722),
      tintOpacityTop: 0.82,
      tintOpacityBottom: 0.68,
      borderOpacity: 0.16,
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      shadow: shadow,
      alignment: alignment,
      child: child,
    );
  }

  /// Brand-blue tinted glass for primary actions/selection states.
  factory GlassContainer.tinted({
    Key? key,
    required Widget child,
    Color tint = const Color(0xFF0079EB),
    double borderRadius = 24,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    bool shadow = true,
    AlignmentGeometry? alignment,
  }) {
    return GlassContainer._raw(
      key: key,
      blur: true,
      blurSigma: 20,
      tint: tint,
      tintOpacityTop: 0.88,
      tintOpacityBottom: 0.72,
      borderOpacity: 0.55,
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      shadow: shadow,
      alignment: alignment,
      child: child,
    );
  }

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool blur;
  final double blurSigma;
  final Color tint;
  final double tintOpacityTop;
  final double tintOpacityBottom;
  final double borderOpacity;
  final double borderWidth;
  final bool shadow;
  final Color? shadowColor;
  final AlignmentGeometry? alignment;

  DecoratedBox _fill(BorderRadius radius, {required bool glass}) {
    // Dark tints read better with a soft light-on-dark border than the
    // bright-white edge used for light glass.
    final isDark = tint.computeLuminance() < 0.5;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? null : Color.alphaBlend(tint, const Color(0xFFF4F5F7)),
        gradient: !glass
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, .45, .8, 1],
                colors: [
                  tint.withValues(alpha: tintOpacityTop),
                  tint.withValues(alpha: tintOpacityBottom),
                  tint.withValues(alpha: tintOpacityBottom),
                  tint.withValues(alpha: (tintOpacityBottom + .12).clamp(0, 1)),
                ],
              ),
        border: Border.all(
          color: !glass
              ? (isDark
                    ? Color.lerp(tint, Colors.white, .16)!
                    : const Color(0xFFE3E9F0))
              : Colors.white.withValues(alpha: borderOpacity),
          width: borderWidth,
        ),
        borderRadius: radius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final glass = usesGlassMaterial(context);

    final surface = usesNativeLiquidGlass(context)
        ? NativeLiquidSurface(
            radius: borderRadius,
            tint: tint == Colors.white ? null : tint.withValues(alpha: .65),
          )
        : ClipRRect(
            borderRadius: radius,
            child: blur && glass
                ? BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: _fill(radius, glass: glass),
                  )
                : _fill(radius, glass: glass),
          );

    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: alignment == null
          ? child
          : Align(alignment: alignment!, child: child),
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      // Tight, low blur radius — most cards in this app sit only 8-16px
      // apart (stacked sections, chip rows), and the old 24px blur bled
      // across gaps that small, fusing separate cards into one glowing
      // blob instead of reading as distinct floating panels.
      decoration: shadow
          ? BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: (shadowColor ?? const Color(0xFF0F172A)).withValues(
                    alpha: glass ? 0.10 : 0.05,
                  ),
                  blurRadius: glass ? 14 : 6,
                  offset: Offset(0, glass ? 5 : 2),
                ),
              ],
            )
          : null,
      // `passthrough` forwards this Stack's own incoming constraints to
      // `content` unchanged — when [height]/[width] are set, that's a tight
      // box, so a Stack+Positioned decoration inside `child` (e.g. an icon
      // pinned to the bottom-right corner) fills the full card instead of
      // collapsing to the size of its non-positioned siblings (`loose`
      // would strip the tightness and shrink `content` down to just its
      // text, pushing Positioned children out of place).
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: surface),
          // Restore the decorated Container's full hit area on iOS. The native
          // backing ignores pointers; otherwise only the text/icon is hittable.
          if (usesNativeLiquidGlass(context))
            const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
          content,
        ],
      ),
    );
  }
}
