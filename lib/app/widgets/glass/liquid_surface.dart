import 'package:flutter/material.dart';
import 'glass_platform.dart';

/// Adapts legacy decorated panels without changing their layout or Android UI.
/// Photos, full-screen backgrounds and undecorated layout boxes are not glass.
class LiquidSurface extends StatelessWidget {
  const LiquidSurface({
    super.key,
    this.child,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
  });
  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding, margin;
  final Color? color;
  final Decoration? decoration, foregroundDecoration;
  final double? width, height;
  final BoxConstraints? constraints;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final box = decoration is BoxDecoration
        ? decoration as BoxDecoration
        : null;
    final native = usesNativeLiquidGlass(context) && _isPanel(box);
    if (!native) {
      return Container(
        alignment: alignment,
        padding: padding,
        color: color,
        decoration: decoration,
        foregroundDecoration: foregroundDecoration,
        width: width,
        height: height,
        constraints: constraints,
        margin: margin,
        transform: transform,
        transformAlignment: transformAlignment,
        clipBehavior: clipBehavior,
        child: child,
      );
    }
    final radius = box!.borderRadius?.resolve(Directionality.of(context));
    final isCircle = box.shape == BoxShape.circle;
    final borderRadius = radius ?? BorderRadius.circular(24);
    final tint = color ?? box.color ?? box.gradient?.colors.first;
    // Keep the original outline: it may indicate selection or validation.
    final content = Container(
      alignment: alignment,
      padding: (padding ?? EdgeInsets.zero).add(box.padding),
      foregroundDecoration: foregroundDecoration,
      width: width,
      height: height,
      constraints: constraints,
      child: child,
    );
    Widget panel = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, bounds) => ClipRRect(
              borderRadius: isCircle
                  ? BorderRadius.circular(bounds.biggest.shortestSide / 2)
                  : borderRadius,
              child: NativeLiquidSurface(
                radius: isCircle
                    ? bounds.biggest.shortestSide / 2
                    : [
                        borderRadius.topLeft.x,
                        borderRadius.topRight.x,
                        borderRadius.bottomLeft.x,
                        borderRadius.bottomRight.x,
                      ].reduce((a, b) => a < b ? a : b),
                tint: liquidSurfaceTint(tint),
              ),
            ),
          ),
        ),
        if (box.border != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: box.shape,
                  borderRadius: isCircle ? null : borderRadius,
                  border: box.border,
                ),
              ),
            ),
          ),
        // Keep padding/empty parts hit-testable just like the original
        // decorated Container, without giving the UIKit view any gestures.
        const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
        content,
      ],
    );
    if (clipBehavior != Clip.none) {
      panel = isCircle
          ? ClipOval(clipBehavior: clipBehavior, child: panel)
          : ClipRRect(
              borderRadius: borderRadius,
              clipBehavior: clipBehavior,
              child: panel,
            );
    }
    return Container(
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      child: panel,
    );
  }
}

bool _isPanel(BoxDecoration? box) =>
    box != null &&
    box.image == null &&
    (box.borderRadius != null || box.shape == BoxShape.circle) &&
    ((box.color?.a ?? 0) > 0 || box.gradient != null || box.border != null);

/// Category selection keeps its border animation while the fill becomes glass.
class LiquidAnimatedSurface extends StatelessWidget {
  const LiquidAnimatedSurface({
    super.key,
    required this.duration,
    required this.decoration,
    this.padding,
    this.width,
    this.child,
  });
  final Duration duration;
  final Decoration decoration;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    if (!usesNativeLiquidGlass(context)) {
      return AnimatedContainer(
        duration: duration,
        decoration: decoration,
        padding: padding,
        width: width,
        child: child,
      );
    }
    return TweenAnimationBuilder<Decoration>(
      tween: DecorationTween(begin: decoration, end: decoration),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : duration,
      child: child,
      builder: (context, value, child) => LiquidSurface(
        decoration: value,
        padding: padding,
        width: width,
        child: child,
      ),
    );
  }
}

/// Same adaptation for legacy message bubbles and pill decorations.
class LiquidDecoratedBox extends StatelessWidget {
  const LiquidDecoratedBox({
    super.key,
    required this.decoration,
    this.position = DecorationPosition.background,
    this.child,
  });
  final Decoration decoration;
  final DecorationPosition position;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (position == DecorationPosition.background &&
        usesNativeLiquidGlass(context) &&
        decoration is BoxDecoration &&
        _isPanel(decoration as BoxDecoration)) {
      return LiquidSurface(decoration: decoration, child: child);
    }
    return DecoratedBox(
      decoration: decoration,
      position: position,
      child: child,
    );
  }
}

/// Rounded Material list rows retain their ink/gesture layer over native glass.
class LiquidMaterial extends StatelessWidget {
  const LiquidMaterial({
    super.key,
    this.type = MaterialType.canvas,
    this.elevation = 0,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.textStyle,
    this.borderRadius,
    this.shape,
    this.borderOnForeground = true,
    this.clipBehavior = Clip.none,
    this.animationDuration = kThemeChangeDuration,
    this.child,
  });
  final MaterialType type;
  final double elevation;
  final Color? color, shadowColor, surfaceTintColor;
  final TextStyle? textStyle;
  final BorderRadiusGeometry? borderRadius;
  final ShapeBorder? shape;
  final bool borderOnForeground;
  final Clip clipBehavior;
  final Duration animationDuration;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final glass =
        usesNativeLiquidGlass(context) &&
        (borderRadius != null ||
            shape != null ||
            type == MaterialType.circle) &&
        (color?.a ?? 1) > 0;
    final material = Material(
      type: type,
      elevation: glass ? 0 : elevation,
      color: glass ? Colors.transparent : color,
      shadowColor: shadowColor,
      surfaceTintColor: glass ? Colors.transparent : surfaceTintColor,
      textStyle: textStyle,
      borderRadius: borderRadius,
      shape: shape,
      borderOnForeground: borderOnForeground,
      clipBehavior: clipBehavior,
      animationDuration: animationDuration,
      child: child,
    );
    if (!glass) return material;
    final radius =
        borderRadius?.resolve(Directionality.of(context)).topLeft.x ??
        (shape is RoundedRectangleBorder
            ? (shape as RoundedRectangleBorder).borderRadius
                  .resolve(Directionality.of(context))
                  .topLeft
                  .x
            : 24.0);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, bounds) => NativeLiquidSurface(
              radius: shape is CircleBorder || type == MaterialType.circle
                  ? bounds.biggest.shortestSide / 2
                  : radius,
              tint: liquidSurfaceTint(color),
            ),
          ),
        ),
        material,
      ],
    );
  }
}

class LiquidInk extends StatelessWidget {
  const LiquidInk({
    super.key,
    this.padding,
    this.color,
    this.decoration,
    this.width,
    this.height,
    this.child,
  });
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final double? width, height;
  final Widget? child;
  @override
  Widget build(BuildContext context) => usesNativeLiquidGlass(context)
      ? LiquidSurface(
          padding: padding,
          color: color,
          decoration: decoration,
          width: width,
          height: height,
          child: child,
        )
      : Ink(
          padding: padding,
          color: color,
          decoration: decoration,
          width: width,
          height: height,
          child: child,
        );
}
