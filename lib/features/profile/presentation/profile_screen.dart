import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/auth/data/client_auth_service.dart';
import 'package:fixleo/features/auth/data/client_model.dart';
import 'package:fixleo/features/welcome/presentation/intro_screen.dart';
import 'package:fixleo/features/request/presentation/my_orders_screen.dart';
import 'package:fixleo/features/settings/presentation/settings_screen.dart';

/// User profile — account header (live `GET /clients/me`) plus grouped settings
/// rows and logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const _gray = Color(0xFF8D96A4);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _red50 = Color(0xFFFEF2F2);
  static const _red700 = Color(0xFFB91C1C);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _gray = ProfileScreen._gray;
  static const _red50 = ProfileScreen._red50;
  static const _red700 = ProfileScreen._red700;

  final _authService = ClientAuthService();
  Client? _client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = await _authService.me();
      if (mounted) setState(() => _client = client);
    } catch (_) {
      // Keep placeholder header if the profile can't be fetched.
    }
  }

  Future<void> _confirmLogout(AppLanguage lang) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(lang, 'Chiqish', 'Выход', 'Sign out')),
        content: Text(tr(
            lang,
            'Akkauntdan chiqmoqchimisiz?',
            'Выйти из аккаунта?',
            'Sign out of your account?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(lang, 'Bekor qilish', 'Отмена', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(lang, 'Chiqish', 'Выйти', 'Sign out')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Profil', 'Профиль', 'Profile'),
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
                  label: tr(lang, 'Mening manzillarim', 'Мои адреса', 'My addresses'),
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.history,
                  label: tr(lang, 'Buyurtmalar tarixi', 'История заказов', 'Order history'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // "History" opens on the Completed tab, not Active.
                        builder: (_) => const MyOrdersScreen(initialTab: 1),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: tr(lang, 'Sozlamalar', 'Настройки', 'Settings'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 8),
              _group([
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  label: tr(lang, 'Bildirishnomalar', 'Уведомления', 'Notifications'),
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.headset_mic_outlined,
                  label: tr(lang, 'Qoʻllab-quvvatlash', 'Поддержка', 'Support'),
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.shield_outlined,
                  label: tr(lang, 'Maxfiylik siyosati', 'Политика конфиденциальности', 'Privacy policy'),
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 8),
              _logout(context, lang),
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
          Text(
            _client?.name ?? '—',
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          Text(
            _client?.phone ?? '',
            style: const TextStyle(
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
  Widget _logout(BuildContext context, AppLanguage lang) {
    return GestureDetector(
      onTap: () => _confirmLogout(lang),
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
            Text(
              tr(lang, 'Akkauntdan chiqish', 'Выйти из аккаунта', 'Sign out'),
              style: const TextStyle(
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
