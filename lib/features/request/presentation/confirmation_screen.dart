import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/order_en_route_screen.dart';

/// Order confirmation — the final step after picking a master.
/// Shows the chosen master, a summary of the request and a confirm button.
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key});

  static const _blue100 = Color(0xFFDBEAFE);
  static const _gray = Color(0xFF8D96A4);

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Tasdiqlash',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _masterCard(),
                    const SizedBox(height: 10),
                    _summaryCard(),
                    const SizedBox(height: 10),
                    _noticeBanner(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // "Tanlovni tasdiqlash" — Figma pill: 52px tall, fully rounded.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OrderEnRouteScreen(),
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
                  'Tanlovni tasdiqlash',
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

  /// Chosen master: avatar, name + rating, price and a "Tanlash" button.
  Widget _masterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person, size: 26, color: _gray),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Aleksey Ivanov',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 24 / 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          size: 15,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.star_rounded, size: 13, color: _gray),
                        SizedBox(width: 5),
                        Text(
                          '4.9 · 124 sharh · 2.4 km',
                          style: TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            letterSpacing: -0.16,
                            color: _gray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    'dan',
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: _gray,
                    ),
                  ),
                  Text(
                    '50 000',
                    style: TextStyle(
                      fontSize: 20,
                      height: 24 / 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // "Tanlash" — secondary action inside the card.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                // TODO: open this master's profile / re-select.
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Tanlash',
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
    );
  }

  /// Request summary: label/value rows separated by flexible spacing.
  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: const [
          _SummaryRow(label: 'Xizmat', value: 'Smesitel almashtirish'),
          SizedBox(height: 8),
          _SummaryRow(label: 'Vaqt', value: 'Bugun, 12:00–15:00'),
          SizedBox(height: 8),
          _SummaryRow(label: 'Usta taklifi', value: '50 000 soʻm'),
        ],
      ),
    );
  }

  /// Light-blue hint shown below the summary.
  Widget _noticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'Tasdiqlangach usta bildirishnoma oladi',
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.16,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

/// A single "label … value" row of the summary card.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

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
            letterSpacing: -0.16,
            color: ConfirmationScreen._gray,
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
              letterSpacing: -0.16,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}
