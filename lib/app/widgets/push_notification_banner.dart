import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fixleo/app/locale/app_locale.dart';

/// One lightweight overlay: entrance/exit animations, swipe-to-dismiss and
/// reduced-motion support. Its timer is owned by the widget and cannot remove
/// a newer notification after this one has been replaced.
class PushNotificationBanner extends StatefulWidget {
  const PushNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.onOpen,
    required this.onDismiss,
  });
  final String title;
  final String body;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  State<PushNotificationBanner> createState() => _PushNotificationBannerState();
}

class _PushNotificationBannerState extends State<PushNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 160),
  );
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _animation.forward();
    _timer = Timer(const Duration(seconds: 5), () => _close());
  }

  Future<void> _close({bool open = false}) async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _animation.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    if (open) widget.onOpen();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final card = Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x26071D39),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _close(open: true),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 42,
                  height: 42,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF102447),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF60708A),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: tr(lang, 'Yopish', 'Закрыть', 'Dismiss'),
                onPressed: () => _close(),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Color(0xFF60708A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      liveRegion: true,
      child: Dismissible(
        key: const ValueKey('push-banner-dismiss'),
        direction: DismissDirection.up,
        resizeDuration: null,
        onDismissed: (_) {
          _timer?.cancel();
          widget.onDismiss();
        },
        child: MediaQuery.disableAnimationsOf(context)
            ? card
            : SlideTransition(
                position: Tween(begin: const Offset(0, -1), end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: _animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: FadeTransition(opacity: _animation, child: card),
              ),
      ),
    );
  }
}
