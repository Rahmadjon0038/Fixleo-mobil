import 'package:flutter/material.dart';
import 'glass_platform.dart';

/// Shows a modal bottom sheet wrapped in a frosted glass surface (blurred
/// scrim + translucent sheet body with a rounded top and a bright top
/// border), replacing the solid-white `showModalBottomSheet` used across
/// ~8 screens (country picker, filters, top-up, attach photos, ...).
///
/// [builder] receives the sheet's inner content — wrap your existing sheet
/// body in it unchanged; padding/SafeArea stay the caller's responsibility
/// exactly as before.
Future<T?> showGlassModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  double topRadius = 28,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) => ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      child: GlassBackdrop(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(
                  alpha: usesNativeLiquidGlass(ctx)
                      ? 0
                      : usesGlassMaterial(ctx)
                      ? 0.80
                      : 1,
                ),
                Colors.white.withValues(
                  alpha: usesNativeLiquidGlass(ctx)
                      ? 0
                      : usesGlassMaterial(ctx)
                      ? 0.66
                      : 1,
                ),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1,
              ),
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(topRadius),
            ),
          ),
          child: Material(color: Colors.transparent, child: builder(ctx)),
        ),
      ),
    ),
  );
}

/// Frosted glass replacement for `AlertDialog`/`SimpleDialog` — same
/// blur + translucent-white material as [showGlassModalBottomSheet], boxed
/// as a centered rounded panel.
class GlassAlertDialog extends StatelessWidget {
  const GlassAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.contentPadding = const EdgeInsets.fromLTRB(24, 20, 24, 8),
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: GlassBackdrop(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(
                    alpha: usesNativeLiquidGlass(context)
                        ? 0
                        : usesGlassMaterial(context)
                        ? 0.80
                        : 1,
                  ),
                  Colors.white.withValues(
                    alpha: usesNativeLiquidGlass(context)
                        ? 0
                        : usesGlassMaterial(context)
                        ? 0.66
                        : 1,
                  ),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: contentPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C274C),
                      ),
                      child: title!,
                    ),
                    const SizedBox(height: 10),
                  ],
                  ?content,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(alignment: WrapAlignment.end, children: actions),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
