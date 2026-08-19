import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';

/// Small white pill used both for the brand badge and screen titles.
/// Deliberately flat (not glass) — matches the FINAL Figma header, which
/// keeps this element plain white against the glass content below it.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small centered brand badge ("logo + FixLeo") shown at the top of
/// every screen.
class BrandBar extends StatelessWidget {
  const BrandBar({super.key});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/logo.svg', width: 28, height: 28),
          const SizedBox(width: 8),
          const Text(
            'FixLeo',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// Set `--dart-define=FIXLEO_SCREENSHOT_MODE=true` to show the brand badge
/// while capturing screenshots. Default is `false` everywhere.
const bool _screenshotMode = bool.fromEnvironment(
  'FIXLEO_SCREENSHOT_MODE',
  defaultValue: false,
);

/// Returns `true` only in screenshot mode.
bool shouldShowBrandBar() {
  return _screenshotMode;
}

/// Round iOS "liquid glass" style back button shown on the left of the
/// sub-header — translucent frosted glass with a bright edge highlight.
/// Tuned lighter (blur 12, not the shared [GlassContainer] default of 20)
/// to match the subtle FINAL Figma header — the stronger default reads as
/// too "glassy" at this small size.
class _BackButton extends StatelessWidget {
  const _BackButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.30),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Base scaffold that pins the [BrandBar] to the top center, with an
/// optional sub-header ([title] pill + back button), and renders [body]
/// below. Use this for every screen to keep the header consistent.
///
/// The whole screen sits on a [GlassBackground] wash so every glass panel
/// inside [body] has visible depth to blur.
class BrandedScaffold extends StatelessWidget {
  const BrandedScaffold({
    super.key,
    required this.body,
    this.title,
    this.showBack = false,
    this.onBack,
    this.showBrand,
    this.backgroundColor = AppColors.background,
  });

  final Widget body;
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;

  /// When null, the brand bar follows screenshot mode.
  final bool? showBrand;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final hasSubHeader = title != null || showBack;
    final showBrandBar = showBrand ?? shouldShowBrandBar();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: GlassBackground(
        baseColor: backgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              if (!showBrandBar) const SizedBox(height: 32),
              if (showBrandBar)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: BrandBar(),
                ),
              if (hasSubHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (title != null)
                          _Pill(
                            child: Text(
                              title!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        if (showBack)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _BackButton(onTap: onBack),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
