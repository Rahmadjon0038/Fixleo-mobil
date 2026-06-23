import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';

/// SMS code confirmation. For now the valid code is hard-coded to "1111".
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _validCode = '1111';

  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == 4) {
      _verify();
    }
  }

  void _verify() {
    if (_code == _validCode) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Kod notoʻgʻri. 1111 ni kiriting')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Tasdiqlash',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'SMS dagi kodni kiriting',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '+998 90 123 45 67 raqamiga yuborildi',
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
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Kodni qayta yuborish 0:59 dan soʻng',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            const Spacer(),
            PrimaryButton(label: 'Tasdiqlash', onPressed: _verify),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.index, required this.state});

  final int index;
  final _OtpScreenState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: TextField(
        controller: state._controllers[index],
        focusNode: state._focusNodes[index],
        onChanged: (v) => state._onChanged(index, v),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.blue, width: 2),
          ),
        ),
      ),
    );
  }
}
