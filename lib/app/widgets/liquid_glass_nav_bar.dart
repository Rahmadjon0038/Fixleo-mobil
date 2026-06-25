import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';

/// One tab in the [LiquidGlassNavBar].
class LiquidGlassNavItem {
  const LiquidGlassNavItem(this.label, this.asset);
  final String label;
  final String asset;
}

/// Floating iOS "liquid glass" bottom navigation bar — translucent, blurred,
/// with a bright edge highlight like a water droplet. Shared by the client
/// and master home screens.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<LiquidGlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        height: 80,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Glass background layer — the blur lives here, with NO
              // interactive children (avoids the macOS mouse_tracker bug).
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white.withValues(alpha: 0.65),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(36),
                  ),
                ),
              ),
              // Interactive layer — sits ON TOP of the blur, not inside it.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / items.length;
                    void selectAt(double dx) {
                      final i = (dx / itemWidth).floor().clamp(
                        0,
                        items.length - 1,
                      );
                      if (i != currentIndex) onTap(i);
                    }

                    // Map the selected index to a -1..1 alignment.
                    final alignX = items.length == 1
                        ? 0.0
                        : currentIndex / (items.length - 1) * 2 - 1;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Tap a tab, or drag a finger across the bar and the
                      // selection follows and lands where you release.
                      onTapDown: (d) => selectAt(d.localPosition.dx),
                      onHorizontalDragStart: (d) =>
                          selectAt(d.localPosition.dx),
                      onHorizontalDragUpdate: (d) =>
                          selectAt(d.localPosition.dx),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Sliding "liquid" highlight — flows from one tab to
                          // the next as the selection changes.
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment(alignX, 0),
                            child: FractionallySizedBox(
                              widthFactor: 1 / items.length,
                              heightFactor: 1,
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0079EB,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < items.length; i++)
                                Expanded(
                                  child: _NavButton(
                                    item: items[i],
                                    active: i == currentIndex,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active});

  final LiquidGlassNavItem item;
  final bool active;

  static const _activeColor = Color(0xFF0079EB);

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 300);
    final color = active ? _activeColor : AppColors.navy;
    // Purely visual — tap/drag is handled by the parent gesture detector.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: active ? 1.12 : 1.0,
          duration: duration,
          curve: Curves.easeOutBack,
          child: SvgPicture.asset(
            item.asset,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: duration,
          curve: Curves.easeOut,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
          child: Text(item.label),
        ),
      ],
    );
  }
}
