import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Local error/success feedback, painted ABOVE the Navigator and modal routes.
/// This is deliberately separate from remote push notifications.
class AppFeedback {
  AppFeedback._(this._host, this._fallback);
  final _AppFeedbackHostState? _host;
  final ScaffoldMessengerState? _fallback;

  static AppFeedback of(BuildContext context) {
    final host = context
        .dependOnInheritedWidgetOfExactType<_FeedbackScope>()
        ?.host;
    return AppFeedback._(
      host,
      host == null ? ScaffoldMessenger.maybeOf(context) : null,
    );
  }

  void showSnackBar(SnackBar message) {
    if (_host != null) {
      _host.show(message);
    } else {
      // Standalone screens/widget tests that do not mount the application host.
      _fallback?.showSnackBar(message);
    }
  }

  void hideCurrentSnackBar() {
    _host?.hide();
    _fallback?.hideCurrentSnackBar();
  }
}

class AppFeedbackHost extends StatefulWidget {
  const AppFeedbackHost({super.key, required this.child});
  final Widget child;

  @override
  State<AppFeedbackHost> createState() => _AppFeedbackHostState();
}

class _AppFeedbackHostState extends State<AppFeedbackHost> {
  SnackBar? _message;
  Timer? _timer;
  int _generation = 0;

  void show(SnackBar message) {
    _timer?.cancel();
    final generation = ++_generation;
    setState(() => _message = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      message.onVisible?.call();
      if (!mounted || generation != _generation) return;
      // Actionable feedback must not disappear before a screen-reader user
      // can reach the action. It remains dismissible by swipe/close button.
      if (MediaQuery.accessibleNavigationOf(context) &&
          message.action != null) {
        return;
      }
      _timer = Timer(message.duration, () {
        if (mounted && generation == _generation) hide();
      });
    });
  }

  void hide() {
    _timer?.cancel();
    ++_generation;
    if (mounted) setState(() => _message = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return _FeedbackScope(
      host: this,
      child: Overlay.wrap(
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (message != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 12,
                right: 12,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 600,
                      maxHeight: math.max(
                        64,
                        (MediaQuery.sizeOf(context).height -
                                MediaQuery.viewInsetsOf(context).bottom -
                                MediaQuery.paddingOf(context).top -
                                24) *
                            .5,
                      ),
                    ),
                    child: _FeedbackBanner(
                      key: ValueKey(_generation),
                      message: message,
                      onDismiss: hide,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackScope extends InheritedWidget {
  const _FeedbackScope({required this.host, required super.child});
  final _AppFeedbackHostState host;
  @override
  bool updateShouldNotify(_FeedbackScope oldWidget) => oldWidget.host != host;
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });
  final SnackBar message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final background = message.backgroundColor ?? const Color(0xFF162747);
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF162747);
    final action = message.action;
    var actionInvoked = false;
    final card = Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: background,
        elevation: 12,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: foreground,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: foreground,
                          fontSize: 15,
                          height: 1.35,
                        ),
                        child: message.content,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: onDismiss,
                      icon: Icon(
                        Icons.close_rounded,
                        color: foreground,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                if (action != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: action.textColor ?? foreground,
                    ),
                    onPressed: () {
                      if (actionInvoked) return;
                      actionInvoked = true;
                      onDismiss();
                      action.onPressed();
                    },
                    child: Text(action.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Dismissible(
      key: key!,
      direction: DismissDirection.up,
      resizeDuration: null,
      onDismissed: (_) => onDismiss(),
      child: MediaQuery.disableAnimationsOf(context)
          ? card
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (_, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -12 * (1 - value)),
                  child: child,
                ),
              ),
              child: card,
            ),
    );
  }
}
