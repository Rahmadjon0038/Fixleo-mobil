import 'package:flutter/material.dart';
import 'glass_platform.dart';

/// Standalone search inputs; editing, selection and IME stay entirely Flutter.
class LiquidSearchField extends StatelessWidget {
  const LiquidSearchField({
    super.key,
    this.controller,
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
    this.style,
    required this.decoration,
  });
  final TextEditingController? controller;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final InputDecoration decoration;
  @override
  Widget build(BuildContext context) {
    final native = usesNativeLiquidGlass(context);
    final field = TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: textInputAction,
      style: style,
      decoration: native
          ? decoration.copyWith(filled: false, fillColor: Colors.transparent)
          : decoration,
    );
    if (!native) return field;
    final border = decoration.border;
    final radius = border is OutlineInputBorder
        ? border.borderRadius.topLeft.x
        : 18.0;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: NativeLiquidSurface(radius: radius)),
        field,
      ],
    );
  }
}

class LiquidChoiceChip extends StatelessWidget {
  const LiquidChoiceChip({
    super.key,
    required this.selected,
    required this.label,
    this.onSelected,
    this.labelStyle,
    this.selectedColor,
    this.backgroundColor,
    this.side,
    this.showCheckmark = false,
    this.shape,
  });
  final bool selected, showCheckmark;
  final Widget label;
  final ValueChanged<bool>? onSelected;
  final TextStyle? labelStyle;
  final Color? selectedColor, backgroundColor;
  final BorderSide? side;
  final OutlinedBorder? shape;
  @override
  Widget build(BuildContext context) {
    final native = usesNativeLiquidGlass(context);
    final chip = ChoiceChip(
      selected: selected,
      onSelected: onSelected,
      label: label,
      labelStyle: labelStyle,
      side: side,
      shape: shape,
      showCheckmark: showCheckmark,
      selectedColor: native ? Colors.transparent : selectedColor,
      backgroundColor: native ? Colors.transparent : backgroundColor,
    );
    return _chipSurface(
      context,
      chip,
      selected ? selectedColor : backgroundColor,
      shape,
    );
  }
}

class LiquidFilterChip extends StatelessWidget {
  const LiquidFilterChip({
    super.key,
    required this.selected,
    required this.label,
    this.onSelected,
    this.labelStyle,
    this.selectedColor,
    this.backgroundColor,
    this.checkmarkColor,
    this.side,
    this.shape,
  });
  final bool selected;
  final Widget label;
  final ValueChanged<bool>? onSelected;
  final TextStyle? labelStyle;
  final Color? selectedColor, backgroundColor, checkmarkColor;
  final BorderSide? side;
  final OutlinedBorder? shape;
  @override
  Widget build(BuildContext context) {
    final native = usesNativeLiquidGlass(context);
    final chip = FilterChip(
      selected: selected,
      onSelected: onSelected,
      label: label,
      labelStyle: labelStyle,
      side: side,
      shape: shape,
      checkmarkColor: checkmarkColor,
      selectedColor: native ? Colors.transparent : selectedColor,
      backgroundColor: native ? Colors.transparent : backgroundColor,
    );
    return _chipSurface(
      context,
      chip,
      selected ? selectedColor : backgroundColor,
      shape,
    );
  }
}

Widget _chipSurface(
  BuildContext context,
  Widget chip,
  Color? tint,
  OutlinedBorder? shape,
) {
  if (!usesNativeLiquidGlass(context)) return chip;
  final radius = shape is RoundedRectangleBorder
      ? shape.borderRadius.resolve(Directionality.of(context)).topLeft.x
      : 20.0;
  return Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: Padding(
          // Material chips include a 48dp touch target around a 32dp surface.
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: NativeLiquidSurface(
            radius: radius,
            tint: liquidSurfaceTint(tint),
          ),
        ),
      ),
      chip,
    ],
  );
}
