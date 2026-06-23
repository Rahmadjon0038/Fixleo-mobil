import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/master_profile_screen.dart';

/// A master's response to the request.
class _Master {
  const _Master({
    required this.name,
    required this.rating,
    required this.price,
  });

  final String name;

  /// e.g. "4.9 · 124 sharh · 2.4 km".
  final String rating;
  final String price;
}

/// Step 7 of the "new request" flow — the list of masters who responded,
/// each with a price the user can accept or decline.
class MastersResponsesScreen extends StatelessWidget {
  const MastersResponsesScreen({super.key});

  static const _gray = Color(0xFF8D96A4);
  static const _slate100 = Color(0xFFF1F5F9);

  static const _masters = [
    _Master(
      name: 'Aleksey Ivanov',
      rating: '4.9 · 124 sharh · 2.4 km',
      price: '50 000',
    ),
    _Master(
      name: 'Dmitriy Petrov',
      rating: '4.8 · 98 sharh · 3.1 km',
      price: '45 000',
    ),
    _Master(
      name: 'Dmitriy Petrov',
      rating: '4.8 · 98 sharh · 3.1 km',
      price: '45 000',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Javoblar · 4',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          // Section header: count + sort chip.
          Row(
            children: [
              const Text(
                '4 usta javob berdi',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF23232E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.star_rounded, size: 16, color: _gray),
                    SizedBox(width: 2),
                    Text(
                      'Reyting boʻyicha',
                      style: TextStyle(fontSize: 12, color: _gray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _masters.length; i++) ...[
            if (i != 0) const SizedBox(height: 10),
            _MasterCard(master: _masters[i]),
          ],
        ],
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.master});

  final _Master master;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar.
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person,
                  size: 26,
                  color: MastersResponsesScreen._gray,
                ),
              ),
              const SizedBox(width: 12),
              // Name + rating.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            master.name,
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
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            master.rating,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              letterSpacing: -0.16,
                              color: MastersResponsesScreen._gray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Price.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'dan',
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: MastersResponsesScreen._gray,
                    ),
                  ),
                  Text(
                    master.price,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 24 / 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _cardButton(
            label: 'Tanlash',
            background: AppColors.blue,
            foreground: Colors.white,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MasterProfileScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _cardButton(
            label: 'Bekor qilish',
            background: MastersResponsesScreen._slate100,
            foreground: AppColors.blue,
            onTap: () {
              // TODO: decline this response.
            },
          ),
        ],
      ),
    );
  }

  Widget _cardButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            height: 22 / 16,
            letterSpacing: -0.18,
            fontWeight: FontWeight.w500,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
