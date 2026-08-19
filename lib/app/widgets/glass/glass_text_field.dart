import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_container.dart';

/// Frosted glass input field — the shared replacement for the ad hoc
/// solid-white rounded `TextField` containers duplicated across ~19 screens
/// (phone entry, addresses, request forms, chat composer, etc).
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.hasError = false,
    this.height = 56,
    this.leading,
    this.trailing,
    this.textStyle,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool hasError;

  /// Fixed height for single-line fields. Pass `null` for multiline fields
  /// that should size to their content.
  final double? height;
  final Widget? leading;
  final Widget? trailing;
  final TextStyle? textStyle;
  final bool autofocus;
  final bool enabled;

  static const _navy = Color(0xFF1C274C);
  static const _muted = Color(0xFF94A3B8);
  static const _danger = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      readOnly: readOnly,
      autofocus: autofocus,
      enabled: enabled,
      style:
          textStyle ??
          const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
      ),
    );

    final row = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(child: field),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );

    return GlassContainer(
      height: height,
      borderRadius: 16,
      // `isCollapsed: true` strips the TextField's own padding, so a
      // multiline field (height: null) needs its own vertical padding here —
      // otherwise the pill shrinks to exactly the text's line height, far
      // shorter than the round buttons it sits next to in a composer row.
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: height == null ? 12 : 0,
      ),
      borderOpacity: hasError ? 0.0 : 0.75,
      alignment: height != null ? Alignment.centerLeft : null,
      child: hasError
          ? Container(
              decoration: BoxDecoration(
                border: Border.all(color: _danger, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: row,
            )
          : row,
    );
  }
}
