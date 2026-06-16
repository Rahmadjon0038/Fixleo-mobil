import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';

/// Small white pill used both for the brand badge and screen titles.
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

/// Round iOS "liquid glass" style back button shown on the left of the
/// sub-header — translucent frosted glass with a bright edge highlight.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
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
class BrandedScaffold extends StatelessWidget {
  const BrandedScaffold({
    super.key,
    required this.body,
    this.title,
    this.showBack = false,
    this.showBrand = true,
    this.backgroundColor = AppColors.background,
  });

  final Widget body;
  final String? title;
  final bool showBack;

  /// When false, the pinned [BrandBar] is not rendered — the screen is
  /// expected to include its own (e.g. scrolling with the content).
  final bool showBrand;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final hasSubHeader = title != null || showBack;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            if (showBrand)
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
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _BackButton(),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
