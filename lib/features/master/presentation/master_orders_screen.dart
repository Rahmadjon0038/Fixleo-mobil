import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';

/// Order status shown as a colored pill on each history card.
enum _OrderStatus { done, cancelled }

/// A finished or cancelled job in the master's work history.
class _Order {
  const _Order({
    required this.title,
    required this.desc,
    required this.address,
    required this.date,
    required this.price,
    required this.status,
  });

  final String title;
  final String desc;
  final String address;
  final String date;
  final String price;
  final _OrderStatus status;
}

/// Master's "My work" — order history and reviews, shown under the "Zakazlar"
/// tab. A segmented control switches between the history list and reviews.
class MasterOrdersScreen extends StatefulWidget {
  const MasterOrdersScreen({super.key});

  @override
  State<MasterOrdersScreen> createState() => _MasterOrdersScreenState();
}

class _MasterOrdersScreenState extends State<MasterOrdersScreen> {
  static const _orders = <_Order>[
    _Order(
      title: 'Rozetka tuzatildi',
      desc: 'Rozetka ishlamay qoldi, uchqun chiqyapti.',
      address: 'Lenin koʻchasi, 123, 12-xonadon',
      date: '22-iyun 2026, 15:40',
      price: '50 000 soʻm',
      status: _OrderStatus.done,
    ),
    _Order(
      title: 'Rozetka tuzatildi',
      desc: 'Rozetka ishlamay qoldi, uchqun chiqyapti.',
      address: 'Lenin koʻchasi, 123, 12-xonadon',
      date: '22-iyun 2026, 15:40',
      price: '50 000 soʻm',
      status: _OrderStatus.cancelled,
    ),
    _Order(
      title: 'Smesitel almashtirildi',
      desc: 'Oshxonada smesitel oqyapti, kartrij almashtirildi.',
      address: 'Amir Temur 12, 45-xonadon',
      date: '20-iyun 2026, 13:10',
      price: '80 000 soʻm',
      status: _OrderStatus.cancelled,
    ),
    _Order(
      title: 'Lyustra oʻrnatildi',
      desc: 'Zalda yangi lyustra oʻrnatib berildi.',
      address: 'Chilonzor 9, 3-xonadon',
      date: '18-iyun 2026, 11:25',
      price: '60 000 soʻm',
      status: _OrderStatus.done,
    ),
  ];

  int _segment = 0; // 0 = Tarix, 1 = Sharhlar.

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          _segmentedControl(),
          const SizedBox(height: 10),
          Expanded(
            child: _segment == 0 ? _history() : _reviews(),
          ),
        ],
      ),
    );
  }

  /// Pill-shaped two-segment control (Tarix / Sharhlar).
  Widget _segmentedControl() {
    return Container(
      height: 41,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(296),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _segmentButton('Tarix', 0),
          _segmentButton('Sharhlar', 1),
        ],
      ),
    );
  }

  Widget _segmentButton(String label, int index) {
    final active = _segment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segment = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEDEDED) : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _history() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _OrderCard(order: _orders[index]),
    );
  }

  Widget _reviews() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: const [
        _RatingSummary(),
        SizedBox(height: 10),
        _ReviewCard(
          name: 'Dilshod R.',
          stars: 5,
          text: 'Vaqtida keldi, hammasini ozoda qildi. Tavsiya qilaman!',
        ),
        SizedBox(height: 10),
        _ReviewCard(
          name: 'Nigora A.',
          stars: 5,
          text: 'Juda tez va sifatli ishladi. Rahmat!',
        ),
        SizedBox(height: 10),
        _ReviewCard(
          name: 'Bekzod T.',
          stars: 4,
          text: 'Yaxshi usta, lekin biroz kechikdi.',
        ),
      ],
    );
  }
}

/// Rating summary card: big average, stars, total count and a 5→1 bar chart.
class _RatingSummary extends StatelessWidget {
  const _RatingSummary();

  // Fill fraction of each distribution bar (5 stars down to 1).
  static const _distribution = [0.9, 0.55, 0.18, 0.06, 0.04];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '4.9',
                style: TextStyle(
                  fontSize: 40,
                  height: 48 / 40,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              const _Stars(count: 5, size: 12),
              const SizedBox(height: 2),
              Text(
                '124 sharh',
                style: const TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  letterSpacing: -0.12,
                  color: Color(0xFF8D96A4),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i != 0) const SizedBox(height: 5),
                  _DistributionRow(
                    label: 5 - i,
                    fraction: _distribution[i],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One "n ▮▮▮▯▯" distribution row in the rating summary.
class _DistributionRow extends StatelessWidget {
  const _DistributionRow({required this.label, required this.fraction});

  final int label;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label',
          style: const TextStyle(
            fontSize: 12,
            height: 16 / 12,
            letterSpacing: -0.12,
            color: Color(0xFF8D96A4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 6, color: const Color(0xFFE2E8F0)),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 6, color: AppColors.blue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single client review card.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.name,
    required this.stars,
    required this.text,
  });

  final String name;
  final int stars;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              _Stars(count: stars, size: 15),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: Color(0xFF8D96A4),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of amber stars.
class _Stars extends StatelessWidget {
  const _Stars({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: const Color(0xFFFFB800),
          ),
      ],
    );
  }
}

/// White card: order info on the left, status pill + price on the right.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final _Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.title,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.desc,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.address,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: Color(0xFF8D96A4),
                    ),
                  ),
                  Text(
                    order.date,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: Color(0xFF8D96A4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusPill(status: order.status),
                Text(
                  order.price,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Blue "Bajarildi" or gray "Bekor qilindi" status pill.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == _OrderStatus.done;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF0F9FF) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        done ? 'Bajarildi' : 'Bekor qilindi',
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.16,
          fontWeight: FontWeight.w600,
          color: done ? AppColors.blue : const Color(0xFF64748B),
        ),
      ),
    );
  }
}
