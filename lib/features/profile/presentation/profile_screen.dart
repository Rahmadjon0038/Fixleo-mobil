import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/account_delete_confirmation.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/full_screen_image_viewer.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/media/avatar_picker.dart';
import 'package:fixleo/features/auth/data/client_auth_service.dart';
import 'package:fixleo/features/auth/data/client_model.dart';
import 'package:fixleo/features/welcome/presentation/intro_screen.dart';
import 'package:fixleo/features/request/presentation/my_orders_screen.dart';
import 'package:fixleo/features/settings/presentation/settings_screen.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/features/notifications/presentation/notifications_screen.dart';
import 'package:fixleo/features/profile/presentation/my_addresses_screen.dart';

/// User profile — account header (live `GET /clients/me`) plus grouped settings
/// rows and logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.embedded = false, this.service});

  final bool embedded;
  final ClientAuthService? service;

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

  late final ClientAuthService _authService =
      widget.service ?? ClientAuthService();
  final _picker = ImagePicker();
  Client? _client;
  bool _avatarBusy = false;
  bool _logoutBusy = false;

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

  Future<void> _chooseAvatarSource() async {
    if (_avatarBusy) return;
    final lang = LocaleController.language.value;
    final action = await showGlassModalBottomSheet<String>(
      context: context,
      topRadius: 24,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                tr(
                  lang,
                  'Galereyadan tanlash',
                  'Выбрать из галереи',
                  'Choose from gallery',
                ),
              ),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(
                tr(lang, 'Kamera bilan olish', 'Сделать фото', 'Take a photo'),
              ),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            if (_client?.avatarUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: Text(
                  tr(lang, 'Rasmni oʻchirish', 'Удалить фото', 'Delete photo'),
                  style: const TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      await _deleteAvatar();
    } else if (action == 'gallery' || action == 'camera') {
      final path = await pickAndCropAvatar(
        picker: _picker,
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (path != null) await _uploadAvatar(path);
    }
  }

  Future<void> _uploadAvatar(String path) async {
    setState(() => _avatarBusy = true);
    try {
      final updated = await _authService.uploadAvatar(path);
      if (!mounted) return;
      setState(() => _client = updated);
      await CurrentUser.instance.refresh();
    } on ApiException catch (e) {
      _showAvatarError(e.message);
    } catch (_) {
      _showAvatarError(
        tr(
          LocaleController.language.value,
          'Rasmni yuklab boʻlmadi',
          'Не удалось загрузить фото',
          'Could not upload photo',
        ),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _avatarBusy = true);
    try {
      final updated = await _authService.deleteAvatar();
      if (!mounted) return;
      setState(() => _client = updated);
      await CurrentUser.instance.refresh();
    } on ApiException catch (e) {
      _showAvatarError(e.message);
    } catch (_) {
      _showAvatarError(
        tr(
          LocaleController.language.value,
          'Rasmni oʻchirib boʻlmadi',
          'Не удалось удалить фото',
          'Could not delete photo',
        ),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  void _showAvatarError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// FINAL profile has a «Язык» row — quick in-place picker.
  Future<void> _pickLanguage() async {
    final lang = LocaleController.language.value;
    final picked = await showDialog<AppLanguage>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: Text(tr(lang, 'Til', 'Язык', 'Language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in const [
              (AppLanguage.uz, 'Oʻzbekcha'),
              (AppLanguage.ru, 'Русский'),
              (AppLanguage.en, 'English'),
            ])
              InkWell(
                onTap: () => Navigator.of(ctx).pop(entry.$1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.$2)),
                      if (lang == entry.$1)
                        const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.blue,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      LocaleController.set(picked);
      if (mounted) setState(() {});
    }
  }

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
    await _logoutAndReturnToIntro();
  }

  Future<void> _logoutAndReturnToIntro() async {
    if (_logoutBusy) return;
    setState(() => _logoutBusy = true);
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmDeleteAccount(AppLanguage lang) async {
    if (_logoutBusy) return;
    final confirmed = await showAccountDeleteConfirmation(
      context: context,
      language: lang,
    );
    if (!confirmed || !mounted) return;
    await _logoutAndReturnToIntro();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Profil', 'Профиль', 'Profile'),
      showBack: !widget.embedded,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, widget.embedded ? 100 : 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _userCard(),
              const SizedBox(height: 8),
              _group([
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  label: tr(
                    lang,
                    'Mening manzillarim',
                    'Мои адреса',
                    'My addresses',
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MyAddressesScreen(),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.history,
                  label: tr(
                    lang,
                    'Buyurtmalar tarixi',
                    'История заказов',
                    'Order history',
                  ),
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
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                    await _load();
                  },
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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const NotificationsScreen(kind: 'client'),
                      ),
                    );
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
                _MenuItem(
                  icon: Icons.language_outlined,
                  label: tr(lang, 'Til', 'Язык', 'Language'),
                  onTap: _pickLanguage,
                ),
              ]),
              const SizedBox(height: 8),
              _logout(context, lang),
              const SizedBox(height: 8),
              _deleteAccount(lang),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar + name + phone header card.
  Widget _userCard() {
    return GlassContainer(
      height: 155,
      alignment: Alignment.center,
      borderRadius: 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                // The photo itself opens full-screen when there is one;
                // with no photo yet, tapping it starts the same pick flow
                // as the edit badge.
                onTap: _client?.avatarUrl != null
                    ? () => showFullScreenImage(context, _client!.avatarUrl!)
                    : _chooseAvatarSource,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    // Was AppColors.background (the page's own base fill) —
                    // painted opaque on top of the translucent glass card,
                    // it read as a mismatched gray patch instead of blending
                    // in. Plain white sits naturally on the glass tint.
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _client?.avatarUrl != null
                      ? Image.network(
                          _client!.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.person, size: 38, color: _gray),
                        )
                      : const Icon(Icons.person, size: 38, color: _gray),
                ),
              ),
              Positioned(
                right: -5,
                bottom: -5,
                child: GestureDetector(
                  onTap: _chooseAvatarSource,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: _avatarBusy
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
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
            _fmtPhone(_client?.phone ?? ''),
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

  /// "+998201001010" → "+998 20 100 10 10" (FINAL header format).
  static String _fmtPhone(String phone) {
    final m = RegExp(r'^\+998(\d{2})(\d{3})(\d{2})(\d{2})$').firstMatch(phone);
    if (m == null) return phone;
    return '+998 ${m[1]} ${m[2]} ${m[3]} ${m[4]}';
  }

  /// A frosted glass card grouping menu rows separated by dividers.
  Widget _group(List<_MenuItem> items) {
    return GlassContainer(
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

  /// Red logout pill.
  Widget _logout(BuildContext context, AppLanguage lang) {
    return GestureDetector(
      onTap: () => _confirmLogout(lang),
      child: GlassContainer(
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

  /// Store-facing account action. Until the destructive backend flow is
  /// enabled, confirmation is followed by the same safe session logout.
  Widget _deleteAccount(AppLanguage lang) {
    return GestureDetector(
      onTap: _logoutBusy ? null : () => _confirmDeleteAccount(lang),
      child: GlassContainer(
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
              child: const Icon(Icons.delete_outline, size: 22, color: _red700),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(
                  lang,
                  'Akkauntni o‘chirish',
                  'Удалить аккаунт',
                  'Delete account',
                ),
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
