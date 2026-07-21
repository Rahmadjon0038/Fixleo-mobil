import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/core/realtime/call_service.dart';

/// Full-screen voice-call UI — shows the peer, the call state (calling /
/// incoming / active), and controls (mute, hang up, answer, decline). Driven
/// entirely by [CallService.instance]; pops itself when the call ends.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _call = CallService.instance;

  @override
  void initState() {
    super.initState();
    _call.state.addListener(_onState);
  }

  void _onState() {
    if (!mounted) return;
    if (_call.state.value == CallState.idle || _call.state.value == CallState.ended) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _call.state.removeListener(_onState);
    super.dispose();
  }

  String _label(AppLanguage lang) => switch (_call.state.value) {
        CallState.calling => tr(lang, 'Chaqirilmoqda…', 'Вызов…', 'Calling…'),
        CallState.incoming => tr(lang, 'Kiruvchi qoʻngʻiroq', 'Входящий звонок', 'Incoming call'),
        CallState.active => tr(lang, 'Suhbatda', 'В разговоре', 'On call'),
        _ => tr(lang, 'Qoʻngʻiroq tugadi', 'Звонок завершён', 'Call ended'),
      };

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final s = _call.state.value;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String?>(
                valueListenable: _call.peerName,
                builder: (_, name, _) => Text(
                  name ?? tr(lang, 'Foydalanuvchi', 'Пользователь', 'User'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _label(lang),
                style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.7)),
              ),
              const Spacer(),
              if (s == CallState.incoming)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleAction(
                      color: const Color(0xFFEF4444),
                      icon: Icons.call_end,
                      label: tr(lang, 'Rad etish', 'Отклонить', 'Decline'),
                      onTap: _call.reject,
                    ),
                    _CircleAction(
                      color: const Color(0xFF22C55E),
                      icon: Icons.call,
                      label: tr(lang, 'Qabul qilish', 'Принять', 'Accept'),
                      onTap: _call.answer,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleAction(
                      color: Colors.white.withValues(alpha: 0.18),
                      icon: _call.isMuted ? Icons.mic_off : Icons.mic,
                      label: tr(lang, 'Ovoz', 'Микрофон', 'Mic'),
                      onTap: () => setState(_call.toggleMute),
                    ),
                    _CircleAction(
                      color: const Color(0xFFEF4444),
                      icon: Icons.call_end,
                      label: tr(lang, 'Tugatish', 'Завершить', 'End'),
                      onTap: _call.hangup,
                    ),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}
