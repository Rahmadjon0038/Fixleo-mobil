import 'package:fixleo/app/widgets/app_feedback.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/auth/data/client_auth_service.dart';
import 'package:fixleo/features/auth/presentation/client_name_screen.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_startup_router.dart';

/// SMS code confirmation. Verifies the 4-digit OTP against the backend
/// (`verify-otp`) and routes to the right next step. (Stub code is `1111`.)
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    this.isMaster = false,
    this.resendSeconds = 60,
  });

  /// Full international phone the code was sent to (e.g. `+998901234567`).
  final String phone;

  /// True for the master sign-in flow.
  final bool isMaster;

  /// Seconds before "resend" becomes available again.
  final int resendSeconds;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  final _clientAuth = ClientAuthService();
  final _masterService = MasterService();

  bool _loading = false;
  int _secondsLeft = 0;
  Timer? _timer;

  /// Backend/network error shown inline under the code boxes (wrong code,
  /// expired code, etc.). Cleared as soon as the user edits the code.
  String? _error;

  /// Rate-limit (429) lockout: seconds until verifying is allowed again.
  /// While > 0 the confirm button is disabled and a live countdown message
  /// is shown instead of [_error].
  int _blockSeconds = 0;
  Timer? _blockTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.resendSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blockTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  /// Starts the live 429 lockout countdown (replaces the raw backend
  /// "try again in 354s" text with a readable, ticking message).
  void _startBlock(int seconds) {
    _blockTimer?.cancel();
    setState(() {
      _blockSeconds = seconds;
      _error = null;
    });
    _blockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_blockSeconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _blockSeconds = 0);
      } else {
        if (mounted) setState(() => _blockSeconds--);
      }
    });
  }

  void _onChanged(int index, String value) {
    if (_error != null) setState(() => _error = null);
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == 4) {
      _verify();
    }
  }

  void _snack(String message) {
    AppFeedback.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _verify() async {
    if (_loading || _blockSeconds > 0 || _code.length != 4) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final lang = LocaleController.language.value;
    try {
      if (widget.isMaster) {
        await _verifyMaster();
      } else {
        await _verifyClient();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final wait = e.isRateLimited ? e.retryAfterSeconds : null;
      if (wait != null) {
        _startBlock(wait);
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _error = tr(lang, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyClient() async {
    final result = await _clientAuth.verifyOtp(
      phone: widget.phone,
      code: _code,
    );
    if (!mounted) return;
    if (result.isRegistered) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // New user — collect a name to finish registration.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientNameScreen(phone: widget.phone, code: _code),
        ),
      );
    }
  }

  Future<void> _verifyMaster() async {
    final result = await _masterService.verifyOtp(
      phone: widget.phone,
      code: _code,
    );
    if (!mounted) return;
    final next = await resolveMasterStartupScreen(
      _masterService,
      result.master,
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _loading) return;
    final lang = LocaleController.language.value;
    try {
      final expiresIn = widget.isMaster
          ? await _masterService.resendOtp(widget.phone)
          : await _clientAuth.resendOtp(widget.phone);
      if (!mounted) return;
      _startCountdown(expiresIn >= 60 ? 60 : expiresIn);
      _snack(
        tr(
          lang,
          'Kod qayta yuborildi',
          'Код отправлен повторно',
          'Code resent',
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // 429 carries the seconds to wait — block the button accordingly and
      // show a readable message (the resend line itself ticks the time down).
      final wait = e.retryAfterSeconds;
      if (wait != null) _startCountdown(wait);
      setState(
        () => _error = e.isRateLimited && wait != null
            ? tr(
                lang,
                'Soʻrovlar juda koʻp — biroz kutib turing',
                'Слишком много запросов — немного подождите',
                'Too many requests — please wait a bit',
              )
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _error = tr(lang, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
      );
    }
  }

  /// Human-friendly phone label for the confirmation screen.
  ///
  /// The auth flow supports multiple countries, so the display format must not
  /// assume Uzbekistan-only spacing.
  String get _maskedPhone {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return widget.phone;

    final countryCodeLength = switch (digits) {
      String s when s.startsWith('998') => 3,
      String s when s.startsWith('996') => 3,
      String s when s.startsWith('992') => 3,
      String s when s.startsWith('7') => 1,
      _ => digits.length > 10 ? digits.length - 10 : 0,
    };

    if (countryCodeLength <= 0 || countryCodeLength >= digits.length) {
      return widget.phone;
    }

    final countryCode = digits.substring(0, countryCodeLength);
    final local = digits.substring(countryCodeLength);
    final grouped = <String>[];
    var index = 0;
    final groupSizes = switch (countryCode) {
      '998' => const [2, 3, 2, 2],
      '996' => const [3, 3, 3],
      '992' => const [2, 3, 2, 2],
      '7' => const [3, 3, 2, 2],
      _ => const [3, 3, 3, 3],
    };

    for (final size in groupSizes) {
      if (index >= local.length) break;
      final end = (index + size).clamp(0, local.length);
      grouped.add(local.substring(index, end));
      index = end;
    }
    if (index < local.length) {
      grouped.add(local.substring(index));
    }

    return '+$countryCode ${grouped.join(' ')}'.trim();
  }

  /// "m:ss" for countdown labels (e.g. 354 → "5:54").
  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    // Rate-limit lockout beats a plain error: it ticks down live.
    final errorText = _blockSeconds > 0
        ? tr(
            lang,
            'Urinishlar juda koʻp — ${formatWait(lang, _blockSeconds)} dan '
                'soʻng qayta urinib koʻring',
            'Слишком много попыток — повторите через '
                '${formatWait(lang, _blockSeconds)}',
            'Too many attempts — try again in '
                '${formatWait(lang, _blockSeconds)}',
          )
        : _error;
    return BrandedScaffold(
      title: tr(lang, 'Tasdiqlash', 'Подтверждение', 'Confirmation'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              tr(
                lang,
                'SMS dagi kodni kiriting',
                'Введите код из SMS',
                'Enter the code from SMS',
              ),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                lang,
                '$_maskedPhone raqamiga yuborildi',
                'Отправлено на $_maskedPhone',
                'Sent to $_maskedPhone',
              ),
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i != 0) const SizedBox(width: 14),
                  _OtpBox(index: i, state: this),
                ],
              ],
            ),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: _secondsLeft > 0
                  ? Text(
                      tr(
                        lang,
                        'Kodni qayta yuborish ${_clock(_secondsLeft)} dan soʻng',
                        'Повторная отправка через ${_clock(_secondsLeft)}',
                        'Resend code in ${_clock(_secondsLeft)}',
                      ),
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    )
                  : LiquidActionButton.text(
                      onPressed: _resend,
                      child: Text(
                        tr(
                          lang,
                          'Kodni qayta yuborish',
                          'Отправить код снова',
                          'Resend code',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
            ),
            const Spacer(),
            PrimaryButton(
              label: _loading
                  ? tr(lang, 'Tekshirilmoqda...', 'Проверка...', 'Verifying...')
                  : tr(lang, 'Tasdiqlash', 'Подтвердить', 'Confirm'),
              onPressed: _loading || _blockSeconds > 0 ? null : _verify,
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  const _OtpBox({required this.index, required this.state});

  final int index;
  final _OtpScreenState state;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  @override
  void initState() {
    super.initState();
    widget.state._focusNodes[widget.index].addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.state._focusNodes[widget.index].removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasError =
        widget.state._error != null || widget.state._blockSeconds > 0;
    final focused = widget.state._focusNodes[widget.index].hasFocus;

    // The colored border is drawn here, on a plain fixed-size box, instead
    // of via TextField/InputDecoration — Flutter's InputDecorator computes
    // the OutlineInputBorder's rect from its own internal content height
    // (shrunk whenever isDense/isCollapsed is set to fix vertical centering),
    // which turned the 64x64 square into a pill. Keeping the border and the
    // centering on two separate widgets means neither can distort the other.
    return GlassContainer(
      width: 64,
      height: 64,
      borderRadius: 16,
      padding: EdgeInsets.zero,
      borderOpacity: 0,
      // No drop shadow — 4 boxes sit only 14px apart, and the default soft
      // shadow smears across the gap into one glowing blob behind the row
      // instead of 4 distinct boxes.
      shadow: false,
      child: LiquidSurface(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasError
                ? AppColors.danger
                : focused
                ? AppColors.blue
                : Colors.white.withValues(alpha: 0.75),
            width: hasError ? (focused ? 2 : 1.5) : (focused ? 2 : 1),
          ),
        ),
        child: Center(
          child: TextField(
            controller: widget.state._controllers[widget.index],
            focusNode: widget.state._focusNodes[widget.index],
            onChanged: (v) => widget.state._onChanged(widget.index, v),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
            cursorColor: AppColors.blue,
            decoration: const InputDecoration(
              counterText: '',
              filled: false,
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
