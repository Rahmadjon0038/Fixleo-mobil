import 'package:flutter/material.dart';
import 'glass_platform.dart';

enum _Kind { filled, elevated, outlined, text }

/// Material interaction/semantics are retained; iOS gets a native glass backing.
class LiquidActionButton extends StatelessWidget {
  const LiquidActionButton.filled({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    required this.child,
  }) : _kind = _Kind.filled,
       icon = null,
       iconAlignment = IconAlignment.start;
  const LiquidActionButton.filledIcon({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    this.icon,
    required Widget label,
    this.iconAlignment = IconAlignment.start,
  }) : _kind = _Kind.filled,
       child = label;
  const LiquidActionButton.elevated({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    required this.child,
  }) : _kind = _Kind.elevated,
       icon = null,
       iconAlignment = IconAlignment.start;
  const LiquidActionButton.elevatedIcon({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    this.icon,
    required Widget label,
    this.iconAlignment = IconAlignment.start,
  }) : _kind = _Kind.elevated,
       child = label;
  const LiquidActionButton.outlined({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    required this.child,
  }) : _kind = _Kind.outlined,
       icon = null,
       iconAlignment = IconAlignment.start;
  const LiquidActionButton.outlinedIcon({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    this.icon,
    required Widget label,
    this.iconAlignment = IconAlignment.start,
  }) : _kind = _Kind.outlined,
       child = label;
  const LiquidActionButton.text({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    required this.child,
  }) : _kind = _Kind.text,
       icon = null,
       iconAlignment = IconAlignment.start;
  const LiquidActionButton.textIcon({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.statesController,
    this.icon,
    required Widget label,
    this.iconAlignment = IconAlignment.start,
  }) : _kind = _Kind.text,
       child = label;

  final _Kind _kind;
  final VoidCallback? onPressed, onLongPress;
  final ValueChanged<bool>? onHover, onFocusChange;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final WidgetStatesController? statesController;
  final Widget child;
  final Widget? icon;
  final IconAlignment iconAlignment;

  Widget _button(ButtonStyle? applied) {
    if (icon != null) {
      return switch (_kind) {
        _Kind.filled => FilledButton.icon(
          onPressed: onPressed,
          onLongPress: onLongPress,
          onHover: onHover,
          onFocusChange: onFocusChange,
          style: applied,
          focusNode: focusNode,
          autofocus: autofocus,
          clipBehavior: clipBehavior,
          statesController: statesController,
          icon: icon,
          label: child,
          iconAlignment: iconAlignment,
        ),
        _Kind.elevated => ElevatedButton.icon(
          onPressed: onPressed,
          onLongPress: onLongPress,
          onHover: onHover,
          onFocusChange: onFocusChange,
          style: applied,
          focusNode: focusNode,
          autofocus: autofocus,
          clipBehavior: clipBehavior,
          statesController: statesController,
          icon: icon,
          label: child,
          iconAlignment: iconAlignment,
        ),
        _Kind.outlined => OutlinedButton.icon(
          onPressed: onPressed,
          onLongPress: onLongPress,
          onHover: onHover,
          onFocusChange: onFocusChange,
          style: applied,
          focusNode: focusNode,
          autofocus: autofocus,
          clipBehavior: clipBehavior,
          statesController: statesController,
          icon: icon,
          label: child,
          iconAlignment: iconAlignment,
        ),
        _Kind.text => TextButton.icon(
          onPressed: onPressed,
          onLongPress: onLongPress,
          onHover: onHover,
          onFocusChange: onFocusChange,
          style: applied,
          focusNode: focusNode,
          autofocus: autofocus,
          clipBehavior: clipBehavior,
          statesController: statesController,
          icon: icon,
          label: child,
          iconAlignment: iconAlignment,
        ),
      };
    }
    return switch (_kind) {
      _Kind.filled => FilledButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: applied,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        statesController: statesController,
        child: child,
      ),
      _Kind.elevated => ElevatedButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: applied,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        statesController: statesController,
        child: child,
      ),
      _Kind.outlined => OutlinedButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: applied,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        statesController: statesController,
        child: child,
      ),
      _Kind.text => TextButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        onHover: onHover,
        onFocusChange: onFocusChange,
        style: applied,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        statesController: statesController,
        child: child,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!usesNativeLiquidGlass(context)) return _button(style);
    final states = <WidgetState>{
      if (onPressed == null && onLongPress == null) WidgetState.disabled,
    };
    final theme = Theme.of(context);
    final inherited = switch (_kind) {
      _Kind.filled => theme.filledButtonTheme.style,
      _Kind.elevated => theme.elevatedButtonTheme.style,
      _Kind.outlined => theme.outlinedButtonTheme.style,
      _Kind.text => theme.textButtonTheme.style,
    };
    final merged = (inherited ?? const ButtonStyle()).merge(style);
    final tint =
        merged.backgroundColor?.resolve(states) ??
        (_kind == _Kind.filled ? theme.colorScheme.primary : Colors.white);
    final shape = merged.shape?.resolve(states);
    final radius = shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(Directionality.of(context)).topLeft.x
        : 24.0;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: NativeLiquidSurface(
            radius: radius,
            tint: liquidSurfaceTint(tint),
          ),
        ),
        _button(
          merged.copyWith(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(0),
          ),
        ),
      ],
    );
  }
}
