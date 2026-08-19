import 'package:flutter/material.dart';

import 'glass_container.dart';

/// Frosted glass card — the shared replacement for the half-dozen private
/// solid-white `_Card` widgets duplicated across screens (home, master
/// current-request, offer, order-status, filters, withdraw). Same padding
/// and radius defaults as the old cards so drop-in swaps don't reflow
/// layouts.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(18),
    this.width = double.infinity,
  }) : _lite = false;

  /// Blur-less variant for cards repeated inside a scrolling list (order
  /// rows, request rows) — see [GlassContainer.lite].
  const GlassCard.lite({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(16),
    this.width = double.infinity,
  }) : _lite = true;

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final bool _lite;

  @override
  Widget build(BuildContext context) {
    return _lite
        ? GlassContainer.lite(
            borderRadius: radius,
            padding: padding,
            width: width,
            child: child,
          )
        : GlassContainer(
            borderRadius: radius,
            padding: padding,
            width: width,
            child: child,
          );
  }
}
