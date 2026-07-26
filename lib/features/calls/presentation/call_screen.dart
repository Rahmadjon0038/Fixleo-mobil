import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/core/realtime/call_service.dart';

/// Full-screen client↔master voice-call UI.
///
/// The duration starts only when WebRTC reports a connected audio path. Ringing
/// and connection setup time are deliberately not counted as conversation time.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _call = CallService.instance;
  Timer? _durationTimer;
  DateTime? _activeStartedAt;
  Duration _elapsed = Duration.zero;
  Duration _elapsedAtTimerStart = Duration.zero;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _call.state.addListener(_onState);
    _syncDurationTimer();
  }

  void _onState() {
    if (!mounted) return;
    final current = _call.state.value;
    if (current == CallState.ended) {
      _durationTimer?.cancel();
      if (_closing) return;
      _closing = true;
      setState(() {});
      Future<void>.delayed(const Duration(milliseconds: 750), () {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }
    if (current == CallState.idle) {
      if (!_closing) Navigator.of(context).maybePop();
      return;
    }
    _syncDurationTimer();
    setState(() {});
  }

  void _syncDurationTimer() {
    if (_call.state.value != CallState.active) return;
    _activeStartedAt ??= _call.activeSince ?? DateTime.now();
    if (_durationTimer != null) return;
    final wallElapsed = DateTime.now().difference(_activeStartedAt!);
    _elapsedAtTimerStart = wallElapsed.isNegative ? Duration.zero : wallElapsed;
    _elapsed = _elapsedAtTimerStart;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateElapsed(timer.tick);
    });
  }

  void _updateElapsed(int tick) {
    final startedAt = _activeStartedAt;
    if (!mounted || startedAt == null) return;
    final wallElapsed = DateTime.now().difference(startedAt);
    final tickElapsed = _elapsedAtTimerStart + Duration(seconds: tick);
    final next = wallElapsed > tickElapsed ? wallElapsed : tickElapsed;
    setState(() => _elapsed = next.isNegative ? Duration.zero : next);
  }

  Future<void> _toggleSpeaker() async {
    HapticFeedback.selectionClick();
    try {
      await _call.toggleSpeaker();
      if (mounted) setState(() {});
    } on Object {
      // Keep the call alive if a device cannot switch its audio route.
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _call.state.removeListener(_onState);
    super.dispose();
  }

  String _stateLabel(AppLanguage lang, CallState state) => switch (state) {
    CallState.calling => tr(
      lang,
      'Javob kutilmoqda…',
      'Ожидаем ответа…',
      'Waiting for answer…',
    ),
    CallState.incoming => tr(
      lang,
      'Kiruvchi ovozli qoʻngʻiroq',
      'Входящий аудиозвонок',
      'Incoming voice call',
    ),
    CallState.connecting => tr(
      lang,
      'Xavfsiz aloqa o‘rnatilmoqda…',
      'Устанавливаем соединение…',
      'Connecting securely…',
    ),
    CallState.active => tr(
      lang,
      'Aloqa o‘rnatildi',
      'Соединение установлено',
      'Connected',
    ),
    CallState.busy =>
      _call.statusMessage.value ??
          tr(lang, 'Liniya band', 'Линия занята', 'Line busy'),
    _ => tr(lang, 'Qoʻngʻiroq tugadi', 'Звонок завершён', 'Call ended'),
  };

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final state = _call.state.value;
    final active = state == CallState.active;
    return Scaffold(
      backgroundColor: const Color(0xFF071327),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF15294E), Color(0xFF081326), Color(0xFF050B17)],
            stops: [0, 0.58, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 42,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _TopCallStatus(
                          active: active,
                          duration: _elapsed,
                          waitingLabel: _stateLabel(lang, state),
                          voiceCallLabel: tr(
                            lang,
                            'FixLeo ovozli qo‘ng‘irog‘i',
                            'Аудиозвонок FixLeo',
                            'FixLeo voice call',
                          ),
                        ),
                        const Spacer(flex: 2),
                        ValueListenableBuilder<String?>(
                          valueListenable: _call.peerName,
                          builder: (context, name, _) {
                            final visibleName = name?.trim().isNotEmpty == true
                                ? name!.trim()
                                : tr(
                                    lang,
                                    'Foydalanuvchi',
                                    'Пользователь',
                                    'User',
                                  );
                            return _PeerIdentity(
                              name: visibleName,
                              stateLabel: _stateLabel(lang, state),
                              active: active,
                            );
                          },
                        ),
                        const Spacer(flex: 3),
                        if (state == CallState.incoming)
                          _IncomingActions(
                            declineLabel: tr(
                              lang,
                              'Rad etish',
                              'Отклонить',
                              'Decline',
                            ),
                            acceptLabel: tr(
                              lang,
                              'Qabul qilish',
                              'Принять',
                              'Accept',
                            ),
                            onDecline: () {
                              HapticFeedback.mediumImpact();
                              _call.reject();
                            },
                            onAccept: () {
                              HapticFeedback.mediumImpact();
                              _call.answer();
                            },
                          )
                        else if (state == CallState.calling ||
                            state == CallState.connecting ||
                            state == CallState.active)
                          _ActiveActions(
                            muted: _call.isMuted,
                            speakerOn: _call.isSpeakerOn,
                            micLabel: _call.isMuted
                                ? tr(
                                    lang,
                                    'Mikrofonni yoqish',
                                    'Включить микрофон',
                                    'Unmute',
                                  )
                                : tr(
                                    lang,
                                    'Mikrofon',
                                    'Микрофон',
                                    'Microphone',
                                  ),
                            speakerLabel: tr(
                              lang,
                              'Dinamik',
                              'Динамик',
                              'Speaker',
                            ),
                            endLabel: tr(
                              lang,
                              'Tugatish',
                              'Завершить',
                              'End call',
                            ),
                            onMic: () {
                              HapticFeedback.selectionClick();
                              setState(_call.toggleMute);
                            },
                            onSpeaker: _toggleSpeaker,
                            onEnd: () {
                              HapticFeedback.mediumImpact();
                              _call.hangup();
                            },
                          ),
                        const SizedBox(height: 18),
                        Text(
                          active
                              ? tr(
                                  lang,
                                  'Suhbat davom etmoqda',
                                  'Разговор продолжается',
                                  'Call in progress',
                                )
                              : state == CallState.incoming
                              ? tr(
                                  lang,
                                  'Javob berish uchun yashil tugmani bosing',
                                  'Нажмите зелёную кнопку, чтобы ответить',
                                  'Tap the green button to answer',
                                )
                              : _stateLabel(lang, state),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String formatCallDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

class _TopCallStatus extends StatelessWidget {
  const _TopCallStatus({
    required this.active,
    required this.duration,
    required this.waitingLabel,
    required this.voiceCallLabel,
  });

  final bool active;
  final Duration duration;
  final String waitingLabel;
  final String voiceCallLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          voiceCallLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.66),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            active ? formatCallDuration(duration) : waitingLabel,
            key: ValueKey(active),
            style: TextStyle(
              color: Colors.white,
              fontSize: active ? 28 : 15,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: active ? 1.4 : 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _PeerIdentity extends StatelessWidget {
  const _PeerIdentity({
    required this.name,
    required this.stateLabel,
    required this.active,
  });

  final String name;
  final String stateLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 142,
          height: 142,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: active
                  ? [const Color(0xFF42D89E), AppColors.blue]
                  : [
                      Colors.white.withValues(alpha: 0.32),
                      Colors.white.withValues(alpha: 0.08),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: (active ? AppColors.blue : Colors.black).withValues(
                  alpha: 0.28,
                ),
                blurRadius: 34,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E3458),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF42D89E)
                        : Colors.white.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    stateLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .toList();
    if (words.isEmpty) return 'F';
    return words.map((word) => word.characters.first.toUpperCase()).join();
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({
    required this.declineLabel,
    required this.acceptLabel,
    required this.onDecline,
    required this.onAccept,
  });

  final String declineLabel;
  final String acceptLabel;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallAction(
          key: const Key('call-decline'),
          color: const Color(0xFFE94251),
          icon: Icons.call_end_rounded,
          label: declineLabel,
          size: 76,
          onTap: onDecline,
        ),
        _CallAction(
          key: const Key('call-accept'),
          color: const Color(0xFF28C76F),
          icon: Icons.call_rounded,
          label: acceptLabel,
          size: 76,
          onTap: onAccept,
        ),
      ],
    );
  }
}

class _ActiveActions extends StatelessWidget {
  const _ActiveActions({
    required this.muted,
    required this.speakerOn,
    required this.micLabel,
    required this.speakerLabel,
    required this.endLabel,
    required this.onMic,
    required this.onSpeaker,
    required this.onEnd,
  });

  final bool muted;
  final bool speakerOn;
  final String micLabel;
  final String speakerLabel;
  final String endLabel;
  final VoidCallback onMic;
  final VoidCallback onSpeaker;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CallAction(
            key: const Key('call-mic'),
            color: muted ? Colors.white : Colors.white.withValues(alpha: 0.12),
            foreground: muted ? AppColors.navy : Colors.white,
            icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: micLabel,
            onTap: onMic,
          ),
          _CallAction(
            key: const Key('call-speaker'),
            color: speakerOn
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            foreground: speakerOn ? AppColors.navy : Colors.white,
            icon: speakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            label: speakerLabel,
            onTap: onSpeaker,
          ),
          _CallAction(
            key: const Key('call-end'),
            color: const Color(0xFFE94251),
            icon: Icons.call_end_rounded,
            label: endLabel,
            onTap: onEnd,
          ),
        ],
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.foreground = Colors.white,
    this.size = 68,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: 30, color: foreground),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: 88,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
