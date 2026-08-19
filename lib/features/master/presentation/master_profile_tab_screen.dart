import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_edit_profile_screen.dart';
import 'package:fixleo/features/notifications/presentation/notifications_screen.dart';
import 'package:fixleo/features/welcome/presentation/intro_screen.dart';

/// Master's profile tab — mirrors the client profile layout: account header
/// (live `GET /masters/me`), a working language switcher (O‘zbekcha /
/// Русский / English), grouped settings rows and a logout pill. Shown under
/// the "Profil" tab.
class MasterProfileTabScreen extends StatefulWidget {
  const MasterProfileTabScreen({
    super.key,
    this.onNotificationsChanged,
    this.onOpenWorkHistory,
    this.service,
  });

  final Future<void> Function()? onNotificationsChanged;
  final VoidCallback? onOpenWorkHistory;
  final MasterService? service;

  static const _gray = Color(0xFF8D96A4);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _red50 = Color(0xFFFEF2F2);
  static const _red700 = Color(0xFFB91C1C);

  @override
  State<MasterProfileTabScreen> createState() => _MasterProfileTabScreenState();
}

class _MasterProfileTabScreenState extends State<MasterProfileTabScreen> {
  static const _gray = MasterProfileTabScreen._gray;
  static const _red50 = MasterProfileTabScreen._red50;
  static const _red700 = MasterProfileTabScreen._red700;

  late final MasterService _service = widget.service ?? MasterService();
  Master? _master;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final master = await _service.me();
      if (mounted) setState(() => _master = master);
    } catch (_) {
      // Keep placeholder header if the profile can't be fetched.
    }
  }

  Future<void> _editProfile() async {
    final master = _master;
    if (master == null) return;
    final updated = await Navigator.of(context).push<Master>(
      MaterialPageRoute(
        builder: (_) => MasterEditProfileScreen(master: master),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _master = updated);
    } else {
      await _load();
    }
  }

  /// "+998 90 123 45 67" from the stored `+998...` number (falls back to the
  /// raw value for non-Uzbek numbers).
  String get _prettyPhone {
    final raw = _master?.phone ?? '';
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (!raw.startsWith('+998') || d.length != 12) return raw;
    final local = d.substring(3);
    return '+998 ${local.substring(0, 2)} ${local.substring(2, 5)} '
        '${local.substring(5, 7)} ${local.substring(7, 9)}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.language,
      builder: (context, lang, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          _userCard(),
          const SizedBox(height: 8),
          _languageCard(lang),
          const SizedBox(height: 8),
          _group([
            _MenuItem(
              icon: Icons.person_outline,
              label: tr(lang, 'Mening maʼlumotlarim', 'Мои данные', 'My data'),
              onTap: _editProfile,
            ),
            _MenuItem(
              icon: Icons.history,
              label: tr(lang, 'Ishlar tarixi', 'История работ', 'Work history'),
              onTap: widget.onOpenWorkHistory ?? () {},
            ),
            _MenuItem(
              icon: Icons.settings_outlined,
              label: tr(lang, 'Sozlamalar', 'Настройки', 'Settings'),
              onTap: _editProfile,
            ),
          ]),
          const SizedBox(height: 8),
          _group([
            _MenuItem(
              icon: Icons.notifications_outlined,
              label: tr(
                lang,
                'Bildirishnomalar',
                'Уведомления',
                'Notifications',
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(kind: 'master'),
                  ),
                );
                await widget.onNotificationsChanged?.call();
              },
            ),
            _MenuItem(
              icon: Icons.headset_mic_outlined,
              label: tr(lang, 'Qoʻllab-quvvatlash', 'Поддержка', 'Support'),
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.shield_outlined,
              label: tr(
                lang,
                'Maxfiylik siyosati',
                'Политика конфиденциальности',
                'Privacy policy',
              ),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 8),
          _logout(context, lang),
        ],
      ),
    );
  }

  /// Avatar + name + phone header card.
  Widget _userCard() {
    return GlassContainer(
      width: double.infinity,
      height: 155,
      alignment: Alignment.center,
      borderRadius: 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _editProfile,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: _master?.avatarUrl != null
                  ? Image.network(
                      _master!.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.person, size: 38, color: _gray),
                    )
                  : const Icon(Icons.person, size: 38, color: _gray),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _master?.name ?? '—',
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          Text(
            _prettyPhone,
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

  /// Language switcher card (English / O‘zbekcha / Русский).
  Widget _languageCard(AppLanguage lang) {
    return GlassContainer(
      width: double.infinity,
      borderRadius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(lang, 'Til', 'Язык', 'Language'),
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          _LangOption(
            title: tr(lang, 'O‘zbekcha', 'Узбекский', 'Uzbek'),
            selected: lang == AppLanguage.uz,
            onTap: () => LocaleController.set(AppLanguage.uz),
          ),
          const SizedBox(height: 8),
          _LangOption(
            title: tr(lang, 'Rus tili', 'Русский', 'Russian'),
            selected: lang == AppLanguage.ru,
            onTap: () => LocaleController.set(AppLanguage.ru),
          ),
          const SizedBox(height: 8),
          _LangOption(
            title: tr(lang, 'Ingliz tili', 'Английский', 'English'),
            selected: lang == AppLanguage.en,
            onTap: () => LocaleController.set(AppLanguage.en),
          ),
        ],
      ),
    );
  }

  /// A white rounded card grouping menu rows separated by dividers.
  Widget _group(List<_MenuItem> items) {
    return GlassContainer(
      width: double.infinity,
      borderRadius: 30,
      padding: const EdgeInsets.fromLTRB(10, 4, 20, 4),
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

  /// Confirms, revokes the session (`POST /masters/auth/logout`) and returns
  /// to the onboarding intro.
  Future<void> _confirmLogout(AppLanguage lang) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: Text(tr(lang, 'Chiqish', 'Выход', 'Sign out')),
        content: Text(
          tr(
            lang,
            'Akkauntdan chiqmoqchimisiz?',
            'Выйти из аккаунта?',
            'Sign out of your account?',
          ),
        ),
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
    await _service.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (route) => false,
    );
  }

  /// Red logout pill.
  Widget _logout(BuildContext context, AppLanguage lang) {
    return GestureDetector(
      onTap: () => _confirmLogout(lang),
      child: GlassContainer(
        width: double.infinity,
        borderRadius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            Expanded(
              child: Text(
                tr(lang, 'Akkauntdan chiqish', 'Выйти из аккаунта', 'Sign out'),
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w600,
                  color: _red700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable language row with a radio dot.
class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.blue : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.blue : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
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
                color: MasterProfileTabScreen._slate50,
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
              color: MasterProfileTabScreen._gray,
            ),
          ],
        ),
      ),
    );
  }
}
