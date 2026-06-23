import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/chat_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';

/// "Usta yoʻlda" — the friendly illustration overview of a live order: a
/// 4-step progress bar, the assigned master and the order details. The
/// "Xaritada koʻrish" button opens the map view. Mock data for now.
class OrderEnRouteScreen extends StatelessWidget {
  const OrderEnRouteScreen({super.key});

  static const _sky50 = Color(0xFFF0F9FF);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _text = Color(0xFF23232E);
  static const _muted = Color(0xFF9494A3);
  static const _gray = Color(0xFF8D96A4);

  static const _plants = 'assets/icon/Illustration - Scene Plants.svg';
  static const _person = 'assets/icon/Illustration - humaaans standing 23.svg';

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Buyurtma №1234',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _trackingCard(),
                    const SizedBox(height: 10),
                    _masterCard(context),
                    const SizedBox(height: 10),
                    _detailsCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OrderTrackingScreen(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: const Text(
                  'Xaritada koʻrish',
                  style: TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Illustration + status line + 4-step progress.
  Widget _trackingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: SvgPicture.asset(
                    _plants,
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                  ),
                ),
                SvgPicture.asset(_person, height: 115, width: 92),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: const [
                  _Dot(),
                  SizedBox(width: 4),
                  Text(
                    'Usta yoʻlda',
                    style: TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _sky50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '~15 daqiqa',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _progressBar(),
        ],
      ),
    );
  }

  /// 4-step connected progress: two done, two pending.
  Widget _progressBar() {
    return Row(
      children: [
        _stepNode(done: true),
        _connector(blue: true),
        _stepNode(done: true),
        _connector(blue: false),
        _stepNode(done: false, label: '3'),
        _connector(blue: false),
        _stepNode(done: false, label: '4'),
      ],
    );
  }

  Widget _stepNode({required bool done, String? label}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done ? AppColors.blue : _slate200,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text(
              label ?? '',
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.16,
                color: _gray,
              ),
            ),
    );
  }

  Widget _connector({required bool blue}) {
    return Expanded(
      child: Container(height: 3, color: blue ? AppColors.blue : _slate200),
    );
  }

  /// Assigned master: avatar, name + role, and share / chat quick actions.
  Widget _masterCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _sky50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.person_outline, size: 24, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Aleksey Ivanov',
                  style: TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                Text(
                  'Santexnik · 4.9',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          _actionButton(Icons.link, onTap: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Buyurtma havolasi nusxalandi')),
              );
          }),
          const SizedBox(width: 8),
          _actionButton(Icons.chat_bubble_outline, onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _sky50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColors.blue),
      ),
    );
  }

  /// Order summary rows.
  Widget _detailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: const [
          _DetailRow(label: 'Xizmat', value: 'Smesitel almashtirish'),
          SizedBox(height: 8),
          _DetailRow(label: 'Manzil', value: 'Yunusobod, Amir Temur 12'),
          SizedBox(height: 8),
          _DetailRow(label: 'Narx', value: '50 000 soʻmdan'),
        ],
      ),
    );
  }
}

/// Small blue status dot next to the tracking title.
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: AppColors.blue,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A "label … value" row of the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: OrderEnRouteScreen._muted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: OrderEnRouteScreen._text,
            ),
          ),
        ),
      ],
    );
  }
}
