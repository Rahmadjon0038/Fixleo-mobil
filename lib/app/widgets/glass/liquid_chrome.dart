import 'package:flutter/material.dart';
import 'glass_platform.dart';
import 'liquid_surface.dart';

/// Keeps Material's keyboard, focus, tooltip and touch handling on both OSes.
class LiquidIconControl extends StatelessWidget {
  const LiquidIconControl({super.key, required this.child});
  final IconButton child;

  @override
  Widget build(BuildContext context) {
    if (!usesNativeLiquidGlass(context)) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        const Positioned.fill(child: NativeLiquidSurface(radius: 999)),
        IconButton(
          key: child.key,
          iconSize: child.iconSize,
          visualDensity: child.visualDensity,
          padding: child.padding,
          alignment: child.alignment,
          splashRadius: child.splashRadius,
          color: child.color,
          focusColor: child.focusColor,
          hoverColor: child.hoverColor,
          highlightColor: child.highlightColor,
          splashColor: child.splashColor,
          disabledColor: child.disabledColor,
          onPressed: child.onPressed,
          mouseCursor: child.mouseCursor,
          focusNode: child.focusNode,
          autofocus: child.autofocus,
          tooltip: child.tooltip,
          enableFeedback: child.enableFeedback,
          constraints: child.constraints,
          style: (child.style ?? const ButtonStyle()).copyWith(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(0),
          ),
          isSelected: child.isSelected,
          selectedIcon: child.selectedIcon,
          icon: child.icon,
        ),
      ],
    );
  }
}

/// Standard utility screens use the same floating title material as home/chat.
class LiquidAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiquidAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.surfaceTintColor,
    this.centerTitle,
    this.elevation,
  });
  final Widget? title, leading;
  final List<Widget>? actions;
  final Color? backgroundColor, foregroundColor, surfaceTintColor;
  final bool? centerTitle;
  final double? elevation;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    final native = usesNativeLiquidGlass(context);
    return AppBar(
      backgroundColor: native ? Colors.transparent : backgroundColor,
      surfaceTintColor: native ? Colors.transparent : surfaceTintColor,
      foregroundColor: foregroundColor,
      elevation: native ? 0 : elevation,
      scrolledUnderElevation: native ? 0 : null,
      centerTitle: centerTitle,
      leading:
          leading ??
          (native && Navigator.canPop(context)
              ? LiquidIconControl(
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                )
              : null),
      actions: actions,
      title: native && title != null
          ? LiquidSurface(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: title,
            )
          : title,
    );
  }
}
