import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';
import 'package:fixleo/features/master/presentation/master_chats_screen.dart';
import 'package:fixleo/features/master/presentation/master_filters_screen.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/master/presentation/master_orders_screen.dart';
import 'package:fixleo/features/master/presentation/master_profile_tab_screen.dart';
import 'package:fixleo/features/master/presentation/master_wallet_screen.dart';
import 'package:fixleo/features/master/presentation/master_request_detail_screen.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';

/// A nearby job request shown in the master feed.
class _Request {
  const _Request({
    required this.categoryUz,
    required this.categoryRu,
    required this.categoryEn,
    required this.icon,
    required this.timeUz,
    required this.timeRu,
    required this.timeEn,
    required this.textUz,
    required this.textRu,
    required this.textEn,
    required this.locationUz,
    required this.locationRu,
    required this.locationEn,
  });

  final String categoryUz;
  final String categoryRu;
  final String categoryEn;
  final IconData icon;
  final String timeUz;
  final String timeRu;
  final String timeEn;
  final String textUz;
  final String textRu;
  final String textEn;
  final String locationUz;
  final String locationRu;
  final String locationEn;

  String category(AppLanguage lang) =>
      tr(lang, categoryUz, categoryRu, categoryEn);
  String time(AppLanguage lang) => tr(lang, timeUz, timeRu, timeEn);
  String text(AppLanguage lang) => tr(lang, textUz, textRu, textEn);
  String location(AppLanguage lang) =>
      tr(lang, locationUz, locationRu, locationEn);
}

/// Master dashboard — "nearby requests" feed with the shared liquid-glass
/// bottom navigation. Only the requests tab has content for now.
class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  final List<int> _navHistory = [];

  final MasterMarketplaceService _market = MasterMarketplaceService();
  List<FeedItem> _feedItems = const [];
  bool _feedLoading = true;

  @override
  void initState() {
    super.initState();
    CurrentUser.instance.refresh();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    try {
      final items = await _market.feed();
      if (mounted) setState(() {
        _feedItems = items;
        _feedLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _feedLoading = false);
    }
  }

  _Request _asRequest(FeedItem f) {
    final loc = [
      if (f.district != null) f.district!,
      '${f.distanceKm.toStringAsFixed(1)} km',
    ].join(' · ');
    return _Request(
      categoryUz: f.categoryName, categoryRu: f.categoryName, categoryEn: f.categoryName,
      icon: Icons.build_outlined,
      timeUz: '', timeRu: '', timeEn: '',
      textUz: f.description, textRu: f.description, textEn: f.description,
      locationUz: loc, locationRu: loc, locationEn: loc,
    );
  }

  List<LiquidGlassNavItem> _navItems(AppLanguage lang) => [
    LiquidGlassNavItem(
      tr(lang, 'Buyurtmalar', 'Заявки', 'Requests'),
      'assets/icon/Home.svg',
    ),
    LiquidGlassNavItem(
      tr(lang, 'Zakazlar', 'Заказы', 'Orders'),
      'assets/icon/History.svg',
    ),
    LiquidGlassNavItem(
      tr(lang, 'Chatlar', 'Чаты', 'Chats'),
      'assets/icon/chat.svg',
    ),
    LiquidGlassNavItem(
      tr(lang, 'Hamyon', 'Кошелек', 'Wallet'),
      'assets/icon/wallet.svg',
    ),
    LiquidGlassNavItem(
      tr(lang, 'Profil', 'Профиль', 'Profile'),
      'assets/icon/usericon.svg',
    ),
  ];

  static const _requests = [
    _Request(
      categoryUz: 'Santexnika',
      categoryRu: 'Сантехника',
      categoryEn: 'Plumbing',
      icon: Icons.water_drop_outlined,
      timeUz: '12 daqiqa oldin',
      timeRu: '12 минут назад',
      timeEn: '12 min ago',
      textUz: 'Oshxonada smesitel oqyapti, kartrij almashtirish kerak',
      textRu: 'На кухне течет смеситель, нужно заменить картридж',
      textEn: 'The kitchen mixer is leaking, the cartridge needs replacement',
      locationUz: 'Yunusobod · 2.4 km',
      locationRu: 'Юнусабад · 2.4 км',
      locationEn: 'Yunusabad · 2.4 km',
    ),
    _Request(
      categoryUz: 'Elektrika',
      categoryRu: 'Электрика',
      categoryEn: 'Electrical',
      icon: Icons.bolt_outlined,
      timeUz: '12 daqiqa oldin',
      timeRu: '12 минут назад',
      timeEn: '12 min ago',
      textUz: 'Rozetka ishlamayapti, uchqun chiqyapti',
      textRu: 'Розетка не работает, есть искра',
      textEn: 'The socket is not working, sparks are coming out',
      locationUz: 'Yunusobod · 2.4 km',
      locationRu: 'Юнусабад · 2.4 км',
      locationEn: 'Yunusabad · 2.4 km',
    ),
  ];

  int _navIndex = 0;

  void _setTab(int index) {
    if (index == _navIndex) return;
    _navHistory.add(_navIndex);
    setState(() => _navIndex = index);
  }

  void _goBackTab() {
    if (_navHistory.isNotEmpty) {
      final previous = _navHistory.removeLast();
      setState(() => _navIndex = previous);
      return;
    }
    if (_navIndex != 0) {
      setState(() => _navIndex = 0);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final showBrand = shouldShowBrandBar();
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.language,
      builder: (context, lang, _) {
        final navItems = _navItems(lang);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 8),
                    if (showBrand) const Center(child: BrandBar()),
                    const SizedBox(height: 8),
                    _header(lang, navItems),
                    Expanded(
                      child: switch (_navIndex) {
                        0 => _feed(),
                        1 => const MasterOrdersScreen(),
                        2 => const MasterChatsScreen(),
                        3 => const MasterWalletScreen(),
                        4 => const MasterProfileTabScreen(),
                        _ => const _ComingSoon(),
                      },
                    ),
                  ],
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: LiquidGlassNavBar(
                    items: navItems,
                    currentIndex: _navIndex,
                    onTap: _setTab,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Back · title pill · filter row.
  Widget _header(AppLanguage lang, List<LiquidGlassNavItem> navItems) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _Pill(
              child: Text(
                switch (_navIndex) {
                  0 => tr(
                    lang,
                    'Yoningizdagi buyurtmalar',
                    'Заявки рядом',
                    'Requests nearby',
                  ),
                  1 => tr(lang, 'Mening ishlarim', 'Моя работа', 'My work'),
                  _ => navItems[_navIndex].label,
                },
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _GlassButton(
                onTap: _goBackTab,
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.navy,
                ),
              ),
            ),
            if (_navIndex == 0)
              Align(
                alignment: Alignment.centerRight,
                child: _GlassButton(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MasterFiltersScreen(),
                      ),
                    );
                  },
                  child: SvgPicture.asset(
                    'assets/icon/filter.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      AppColors.navy,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _feed() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _greeting(),
        const SizedBox(height: 10),
        if (_feedLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_feedItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                tr(LocaleController.language.value, 'Hozircha zayavkalar yoʻq',
                    'Пока нет заявок', 'No requests yet'),
                style: const TextStyle(color: Color(0xFF8D96A4)),
              ),
            ),
          )
        else
          for (var i = 0; i < _feedItems.length; i++) ...[
            _RequestCard(
              request: _asRequest(_feedItems[i]),
              onRespond: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MasterRequestDetailScreen(orderId: _feedItems[i].id),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                titleUz: 'Ilova qanday?',
                titleRu: 'Как работает приложение?',
                titleEn: 'How the app works?',
                asset: 'assets/icon/Ranking.svg',
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: _MiniCard(
                titleUz: 'Qoʻllab-quvvatlashga yozish',
                titleRu: 'Написать в поддержку',
                titleEn: 'Write to support',
                asset: 'assets/icon/headphones.svg',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Greeting + location + "change location" pill.
  Widget _greeting() {
    final lang = LocaleController.language.value;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(296),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(296),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.72),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(296),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<UserProfile?>(
                        valueListenable: CurrentUser.instance.profile,
                        builder: (context, profile, _) {
                          final name = profile?.firstName;
                          return Text(
                            name == null
                                ? tr(lang, 'Xayrli kun!', 'Добрый день!', 'Good day!')
                                : tr(lang, 'Xayrli kun, $name!', 'Добрый день, $name!',
                                    'Good day, $name!'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.navy,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            tr(
                              lang,
                              'Yashnobod, Toshkent',
                              'Яшнабад, Ташкент',
                              'Yashnobod, Tashkent',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Text(
                    tr(
                      lang,
                      'Lokatsiyani oʻzgartirish',
                      'Изменить локацию',
                      'Change location',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One request card — category chip, time, description, location, respond.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onRespond});

  final _Request request;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(request.icon, size: 18, color: AppColors.blue),
                    const SizedBox(width: 6),
                    Text(
                      request.category(LocaleController.language.value),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                request.time(LocaleController.language.value),
                style: const TextStyle(fontSize: 14, color: Color(0xFF8D96A4)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.text(LocaleController.language.value),
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w500,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: Color(0xFF8D96A4),
              ),
              const SizedBox(width: 5),
              Text(
                request.location(LocaleController.language.value),
                style: const TextStyle(fontSize: 14, color: Color(0xFF8D96A4)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: onRespond,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Javob berish',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small white card (rate-app / support) at the bottom of the feed.
class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.titleUz,
    required this.titleRu,
    required this.titleEn,
    required this.asset,
  });

  final String titleUz;
  final String titleRu;
  final String titleEn;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Container(
      height: 122,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              tr(lang, titleUz, titleRu, titleEn),
              style: const TextStyle(
                fontSize: 16,
                height: 22 / 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SvgPicture.asset(asset, width: 64, height: 64),
          ),
        ],
      ),
    );
  }
}

/// Placeholder body for tabs other than "requests".
class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Center(
      child: Text(
        tr(lang, 'Tez orada', 'Скоро', 'Coming soon'),
        style: TextStyle(fontSize: 16, color: AppColors.muted),
      ),
    );
  }
}

/// Small white pill used for the header title.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Round iOS "liquid glass" control button (back / filter) — frosted white
/// with a bright edge highlight, matching the app's other glass buttons.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.85),
                    Colors.white.withValues(alpha: 0.55),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
