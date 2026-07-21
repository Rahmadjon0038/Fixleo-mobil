import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/presentation/master_order_status_screen.dart';

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
  final MasterMarketplaceService _market = MasterMarketplaceService();
  List<MasterOrder> _current = const [];
  List<MasterOrder> _historyOrders = const [];
  bool _loading = true;

  int _segment = 0; // 0 = Faol, 1 = Tarix, 2 = Sharhlar.

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _market.orders(status: 'current'),
        _market.orders(status: 'history'),
      ]);
      if (mounted) {
        setState(() {
          _current = results[0];
          _historyOrders = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(AppLanguage lang, String status) => switch (status) {
        'assigned' => tr(lang, 'Tayinlandi', 'Назначен', 'Assigned'),
        'on_the_way' => tr(lang, 'Yoʻlda', 'В пути', 'On the way'),
        'arrived' => tr(lang, 'Yetib keldi', 'На месте', 'Arrived'),
        'work_done' => tr(lang, 'Tasdiq kutilmoqda', 'Ждёт подтверждения', 'Awaiting confirmation'),
        _ => tr(lang, 'Ish jarayonida', 'В работе', 'In progress'),
      };

  static String _money(int? v) {
    if (v == null) return '—';
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  _Order _toOrder(MasterOrder o, AppLanguage lang) {
    final d = o.createdAt;
    final date = d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return _Order(
      title: o.title,
      desc: o.description,
      address: [o.addressText, if (o.addressDetails != null) o.addressDetails!].join(', '),
      date: date,
      price: '${_money(o.price)} ${tr(lang, 'soʻm', 'сум', 'sum')}',
      status: o.status == 'completed' ? _OrderStatus.done : _OrderStatus.cancelled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          _segmentedControl(lang),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : switch (_segment) {
                    0 => _active(lang),
                    1 => _history(_historyOrders.map((o) => _toOrder(o, lang)).toList()),
                    _ => _reviews(lang),
                  },
          ),
        ],
      ),
    );
  }

  /// Pill-shaped two-segment control (Tarix / Sharhlar).
  Widget _segmentedControl(AppLanguage lang) {
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
          _segmentButton(tr(lang, 'Faol', 'Активные', 'Active'), 0),
          _segmentButton(tr(lang, 'Tarix', 'История', 'History'), 1),
          _segmentButton(tr(lang, 'Sharhlar', 'Отзывы', 'Reviews'), 2),
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

  /// Active (in-progress) jobs — each opens the status machine to advance the
  /// order (on the way → arrived → finish). This is where the master actually
  /// works a job after being selected by the client.
  Widget _active(AppLanguage lang) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _current.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    tr(lang, 'Faol buyurtmalar yoʻq', 'Нет активных заказов', 'No active orders'),
                    style: const TextStyle(color: Color(0xFF8D96A4)),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _current.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final o = _current[i];
                return _ActiveOrderCard(
                  title: o.title,
                  desc: o.description,
                  statusLabel: _statusLabel(lang, o.status),
                  address: [o.addressText, if (o.addressDetails != null) o.addressDetails!]
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                  price: '${_money(o.price)} ${tr(lang, 'soʻm', 'сум', 'sum')}',
                  actionLabel: tr(lang, 'Statusni oʻzgartirish', 'Изменить статус', 'Change status'),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => MasterOrderStatusScreen(orderId: o.id)),
                    );
                    if (mounted) _load();
                  },
                );
              },
            ),
    );
  }

  Widget _history(List<_Order> orders) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _OrderCard(order: orders[index]),
    );
  }

  Widget _reviews(AppLanguage lang) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _RatingSummary(),
        SizedBox(height: 10),
        _ReviewCard(
          name: 'Dilshod R.',
          stars: 5,
          text: tr(lang, 'Vaqtida keldi, hammasini ozoda qildi. Tavsiya qilaman!',
              'Пришёл вовремя, всё аккуратно сделал. Рекомендую!', 'Arrived on time and cleaned up everything. Recommended!'),
        ),
        SizedBox(height: 10),
        _ReviewCard(
          name: 'Nigora A.',
          stars: 5,
          text: tr(lang, 'Juda tez va sifatli ishladi. Rahmat!', 'Очень быстро и качественно. Спасибо!', 'Very fast and high quality. Thanks!'),
        ),
        SizedBox(height: 10),
        _ReviewCard(
          name: 'Bekzod T.',
          stars: 4,
          text: tr(lang, 'Yaxshi usta, lekin biroz kechikdi.', 'Хороший мастер, но немного опоздал.', 'Good master, but a bit late.'),
        ),
      ],
    );
  }
}

/// A tappable active-job card — status pill + details + a "change status" hint.
/// Tapping opens the status machine so the master can advance / finish the job.
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.title,
    required this.desc,
    required this.statusLabel,
    required this.address,
    required this.price,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String desc;
  final String statusLabel;
  final String address;
  final String price;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 20 / 14, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF8D96A4)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8D96A4)),
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.blue),
              ],
            ),
          ],
        ),
      ),
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
    final lang = LocaleController.language.value;
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
                tr(lang, '124 sharh', '124 отзыва', '124 reviews'),
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
    final lang = LocaleController.language.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF0F9FF) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        done
            ? tr(lang, 'Bajarildi', 'Выполнено', 'Done')
            : tr(lang, 'Bekor qilindi', 'Отменено', 'Cancelled'),
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
