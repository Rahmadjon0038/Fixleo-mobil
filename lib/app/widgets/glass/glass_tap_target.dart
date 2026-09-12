import 'package:flutter/material.dart';

/// One Flutter gesture owner above decorative native glass and icon/text.
/// Native view channels must not own application actions: a platform view can
/// animate even when the Flutter overlay has prevented its tap callback.
class GlassTapTarget extends StatefulWidget {
  const GlassTapTarget({
    super.key,
    required this.child,
    this.onTap,
    this.label,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  @override
  State<GlassTapTarget> createState() => _GlassTapTargetState();
}

class _GlassTapTargetState extends State<GlassTapTarget> {
  bool _pressed = false;
  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onTap != null,
    label: widget.label,
    onTap: widget.onTap,
    child: FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: AnimatedScale(
              scale: _pressed && widget.onTap != null ? .97 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 100),
              child: widget.child,
            ),
          ),
        ),
      ),
    ),
  );
}
