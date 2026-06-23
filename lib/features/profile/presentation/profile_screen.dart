import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/my_orders_screen.dart';

/// User profile — account header plus grouped settings rows and logout.
/// Mock data for now.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _gray = Color(0xFF8D96A4);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _red50 = Color(0xFFFEF2F2);
  static const _red700 = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Profil',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _userCard(),
              const SizedBox(height: 8),
              _group([
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  label: 'Mening manzillarim',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.history,
                  label: 'Buyurtmalar tarixi',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MyOrdersScreen(),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Sozlamalar',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 8),
              _group([
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  label: 'Bildirishnomalar',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.headset_mic_outlined,
                  label: 'Qoʻllab-quvvatlash',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.shield_outlined,
                  label: 'Maxfiylik siyosati',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 8),
              _logout(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar + name + phone header card.
  Widget _userCard() {
    return Container(
      width: double.infinity,
      height: 155,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person, size: 38, color: _gray),
          ),
          const SizedBox(height: 4),
          const Text(
            'Arslan Koʻpletulov',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const Text(
            '+998 90 000 00 00',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: _gray,
            ),
          ),
        ],
      ),
    );
  }

  /// A white rounded card grouping menu rows separated by dividers.
  Widget _group(List<_MenuItem> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 4, 20, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            items[i],
          ],
        ],
      ),
    );
  }

  /// Red logout pill.
  Widget _logout(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _red50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, size: 22, color: _red700),
            ),
            const SizedBox(width: 10),
            const Text(
              'Akkauntdan chiqish',
              style: TextStyle(
                fontSize: 16,
                height: 22 / 16,
                letterSpacing: -0.18,
                fontWeight: FontWeight.w600,
                color: _red700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable settings row: icon bubble, label and a chevron.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: ProfileScreen._slate50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: ProfileScreen._gray,
            ),
          ],
        ),
      ),
    );
  }
}
