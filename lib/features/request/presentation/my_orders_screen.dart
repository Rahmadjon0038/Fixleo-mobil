import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';

/// Lifecycle status of an order in the list.
enum _OrderStatus { active, done }

/// One row in the orders list.
class _Order {
  const _Order({
    required this.title,
    required this.master,
    required this.date,
    required this.price,
    required this.status,
  });

  final String title;
  final String master;
  final String date;
  final String price;
  final _OrderStatus status;
}

/// "My orders" — the user's orders split into Active and Completed tabs.
/// Mock data for now.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  static const _gray = Color(0xFF8D96A4);
  static const _amber50 = Color(0xFFFFFBEB);
  static const _amber600 = Color(0xFFD97706);
  static const _emerald50 = Color(0xFFECFDF5);
  static const _teal600 = Color(0xFF0D9488);

  static const _orders = <_Order>[
    _Order(
      title: 'Smesitel almashtirish',
      master: 'Aleksey Ivanov · bugun',
      price: '60 000 soʻm',
      date: 'bugun',
      status: _OrderStatus.active,
    ),
    _Order(
      title: 'Smesitel almashtirish',
      master: 'Aleksey Ivanov · bugun',
      price: '60 000 soʻm',
      date: 'bugun',
      status: _OrderStatus.active,
    ),
    _Order(
      title: 'Smesitel almashtirish',
      master: 'Aleksey Ivanov · 25-may',
      price: '60 000 soʻm',
      date: '25-may',
      status: _OrderStatus.done,
    ),
    _Order(
      title: 'Smesitel almashtirish',
      master: 'Aleksey Ivanov · 2-aprel',
      price: '60 000 soʻm',
      date: '2-aprel',
      status: _OrderStatus.done,
    ),
    _Order(
      title: 'Smesitel almashtirish',
      master: 'Aleksey Ivanov · 2-aprel',
      price: '60 000 soʻm',
      date: '2-aprel',
      status: _OrderStatus.done,
    ),
  ];

  /// 0 = Active, 1 = Completed.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final filtered = _orders
        .where((o) =>
            o.status == (_tab == 0 ? _OrderStatus.active : _OrderStatus.done))
        .toList();

    return BrandedScaffold(
      title: 'Mening buyurtmalarim',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            _tabBar(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _orderCard(filtered[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented Active / Completed switch.
  Widget _tabBar() {
    return Container(
      height: 41,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(296),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _tabItem('Faol', 0),
          _tabItem('Yakunlangan', 1),
        ],
      ),
    );
  }

  Widget _tabItem(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          height: 35,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEDEDED) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }

  /// One order card: title + master/date on the left, status + price right.
  Widget _orderCard(_Order order) {
    return Container(
      height: 87,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                Text(
                  order.master,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    color: _gray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusTag(order.status),
              Text(
                order.price,
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusTag(_OrderStatus status) {
    final active = status == _OrderStatus.active;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? _amber50 : _emerald50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          active ? 'Jarayonda' : 'Bajarildi',
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            letterSpacing: -0.12,
            fontWeight: FontWeight.w500,
            color: active ? _amber600 : _teal600,
          ),
        ),
      ),
    );
  }
}
