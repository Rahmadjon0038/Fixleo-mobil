import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';

/// One tab in the [LiquidGlassNavBar].
class LiquidGlassNavItem {
  const LiquidGlassNavItem(this.label, this.asset, {this.badgeCount = 0});
  final String label;
  final String asset;
  final int badgeCount;
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
    return LiquidSurface(
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
              const GlassContainer(
                borderRadius: 36,
                shadow: false,
                child: SizedBox.expand(),
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
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment(alignX, 0),
                            child: FractionallySizedBox(
                              widthFactor: 1 / items.length,
                              heightFactor: 1,
                              child: LiquidSurface(
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
                                  child: Semantics(
                                    button: true,
                                    selected: i == currentIndex,
                                    label: items[i].label,
                                    onTap: () {
                                      if (i != currentIndex) onTap(i);
                                    },
                                    child: ExcludeSemantics(
                                      child: _NavButton(
                                        item: items[i],
                                        active: i == currentIndex,
                                      ),
                                    ),
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
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final color = active ? _activeColor : AppColors.navy;
    // Purely visual — tap/drag is handled by the parent gesture detector.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
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
            if (item.badgeCount > 0)
              Positioned(
                right: -12,
                top: -9,
                child: LiquidSurface(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
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
