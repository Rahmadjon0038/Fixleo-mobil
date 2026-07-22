import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/app.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/profile/presentation/profile_screen.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/chats_list_screen.dart';
import 'package:fixleo/features/request/presentation/my_orders_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';
import 'package:fixleo/features/wallet/presentation/wallet_screen.dart';
import 'package:fixleo/features/request/presentation/new_request_screen.dart';

/// Main home feed shown after a successful login. A single scrollable page
/// with a floating "liquid glass" bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load the real signed-in profile so the greeting shows the actual name.
    CurrentUser.instance.refresh();
    // Voice-call signalling app-wide: an incoming call rings on any screen.
    CallService.instance.connect('client', onIncoming: showIncomingCallUi);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _HomeHeader(lang: lang),
                  const SizedBox(height: 14),
                  _GreetingCard(lang: lang),
                  const SizedBox(height: 14),
                  _SearchHero(lang: lang),
                  const SizedBox(height: 14),
                  _CategoriesCard(lang: lang),
                  const SizedBox(height: 14),
                  const _PhotosCard(),
                  const SizedBox(height: 14),
                  _FeedbackRow(lang: lang),
                  const SizedBox(height: 14),
                  _SpecialistCard(lang: lang),
                  const SizedBox(height: 14),
                  _ActiveOrderCard(lang: lang),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: LiquidGlassNavBar(
              items: [
                LiquidGlassNavItem(
                  tr(lang, 'Asosiy', 'Главная', 'Home'),
                  'assets/icon/Home.svg',
                ),
                LiquidGlassNavItem(
                  tr(lang, 'Buyurtmalar', 'Заказы', 'Orders'),
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
              ],
              currentIndex: _navIndex,
              onTap: (i) async {
                if (i == 0) {
                  setState(() => _navIndex = 0);
                  return;
                }
                setState(() => _navIndex = i);
                // Tabs 1–4 push a full screen. Await it and reset the highlight
                // back to Home on return, so the selected tab never desyncs from
                // the visible screen.
                Widget dest;
                if (i == 1) {
                  dest = const MyOrdersScreen();
                } else if (i == 2) {
                  dest = const LiveChatsScreen(kind: 'client');
                } else if (i == 3) {
                  dest = const WalletScreen();
                } else {
                  dest = const ProfileScreen();
                }
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => dest),
                );
                if (mounted) setState(() => _navIndex = 0);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded white card used for most home sections.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.radius = 26});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-5, -5),
            blurRadius: 12,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            offset: const Offset(5, 9),
            blurRadius: 20,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.asset,
    this.iconSize = 22,
  });

  final String asset;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
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
                      Colors.white.withValues(alpha: 0.65),
                      Colors.white.withValues(alpha: 0.30),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
                child: SvgPicture.asset(
                  asset,
                  width: iconSize,
                  height: iconSize,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                offset: const Offset(-5, -5),
                blurRadius: 12,
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.14),
                offset: const Offset(6, 9),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/logo.svg', width: 30, height: 30),
              const SizedBox(width: 10),
              const Text(
                'FixLeo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const _CircleIconButton(
          // No fabricated unread badge: there's no unread-count source wired yet,
          // so showing a fixed "21" to every user was misleading. Re-add `badge`
          // once a real notifications count endpoint exists.
          asset: 'assets/icon/notificationicon.svg',
          iconSize: 21,
        ),
        const SizedBox(width: 12),
        const _CircleIconButton(
          asset: 'assets/icon/usericon.svg',
          iconSize: 21,
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<UserProfile?>(
                  valueListenable: CurrentUser.instance.profile,
                  builder: (context, profile, _) {
                    final name = profile?.firstName;
                    final text = name == null
                        ? tr(lang, 'Xayrli kun!', 'Добрый день!', 'Good day!')
                        : tr(lang, 'Xayrli kun, $name!', 'Добрый день, $name!',
                            'Good day, $name!');
                    return Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navy,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.navy),
                    SizedBox(width: 4),
                    Text(
                      tr(
                        lang,
                        'Yashnobod, Toshkent',
                        'Яшнабад, Ташкент',
                        'Yashnobod, Tashkent',
                      ),
                      style: TextStyle(
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: 0.30),
                  offset: const Offset(0, 6),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Text(
              tr(
                lang,
                'Lokatsiyani oʻzgartirish',
                'Изменить локацию',
                'Change location',
              ),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHero extends StatelessWidget {
  const _SearchHero({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.heroDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              lang,
              'Har qanday vazifa uchun tekshirilgan\nusta topamiz',
              'Найдём проверенного мастера\nдля любой задачи',
              'We’ll find a vetted master\nfor any task',
            ),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: TextField(
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: tr(
                          lang,
                          'Mutaxassis yoki xizmat',
                          'Специалист или услуга',
                          'Specialist or service',
                        ),
                        hintStyle: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(child: Icon(Icons.search, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Category {
  const _Category(this.label);
  final String label;
}

class _CategoriesCard extends StatefulWidget {
  const _CategoriesCard({required this.lang});

  final AppLanguage lang;

  @override
  State<_CategoriesCard> createState() => _CategoriesCardState();
}

class _CategoriesCardState extends State<_CategoriesCard> {
  final _service = CategoryService();
  late List<_Category> _items;

  @override
  void initState() {
    super.initState();
    _items = _fallback(widget.lang);
    _load();
  }

  List<_Category> _fallback(AppLanguage lang) => [
    _Category(tr(lang, 'Santexnika', 'Сантехника', 'Plumbing')),
    _Category(tr(lang, 'Elektrika', 'Электрика', 'Electrical')),
    _Category(tr(lang, 'Tozalash', 'Уборка', 'Cleaning')),
    _Category(
      tr(lang, 'Maishiy texnika', 'Бытовая техника', 'Home appliances'),
    ),
    _Category(tr(lang, 'Boʻyash', 'Покраска', 'Painting')),
    _Category(tr(lang, 'Yigʻish', 'Сборка', 'Assembly')),
  ];

  Future<void> _load() async {
    try {
      final categories = await _service.getAll();
      if (!mounted || categories.isEmpty) return;
      setState(() {
        _items = categories
            .map((c) => _Category(c.name))
            .toList(growable: false);
      });
    } catch (_) {
      // Keep the fallback list on any error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final half = (_items.length / 2).ceil();
    final row1 = _items.take(half).toList();
    final row2 = _items.skip(half).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(widget.lang, 'Bizning Fix-erlar', 'Наши Fix-еры', 'Our Fix-ers'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                Row(
                  children: [for (final c in row1) _CategoryChip(category: c)],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [for (final c in row2) _CategoryChip(category: c)],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewRequestScreen()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                tr(
                  widget.lang,
                  'Vazifa soʻrash',
                  'Запросить задание',
                  'Request a task',
                ),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-category icon, matched by name keywords (FINAL gives every category a
/// distinct icon; the backend Category model has no icon field yet).
IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('сантех') || n.contains('santex')) {
    return Icons.water_drop_outlined;
  }
  if (n.contains('электр') || n.contains('elektr')) {
    return Icons.bolt_outlined;
  }
  if (n.contains('клин') || n.contains('убор') || n.contains('tozal')) {
    return Icons.cleaning_services_outlined;
  }
  if (n.contains('быт') || n.contains('техник') || n.contains('texnik')) {
    return Icons.kitchen_outlined;
  }
  if (n.contains('крас') || n.contains('boʻyash') || n.contains("bo'yash") ||
      n.contains('paint')) {
    return Icons.format_paint_outlined;
  }
  if (n.contains('сбор') || n.contains('мебел') || n.contains('yigʻ') ||
      n.contains("yig'") || n.contains('mebel')) {
    return Icons.chair_alt_outlined;
  }
  return Icons.handyman_outlined;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final _Category category;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FE),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              _categoryIcon(category.label),
              size: 22,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            category.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard();

  static const _colors = [
    Color(0xFF2C3E50),
    Color(0xFFC79A3B),
    Color(0xFFDCE3DA),
    Color(0xFFE8E2D5),
    Color(0xFFCBD3DA),
    Color(0xFFEAEEF1),
  ];

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              LocaleController.language.value,
              'Ustalar fotosi',
              'Фото Мастеров',
              'Masters’ photos',
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Column(
                children: [
                  _PhotoRow(colors: _colors.sublist(0, 3)),
                  const SizedBox(height: 10),
                  _PhotoRow(colors: _colors.sublist(3, 6)),
                ],
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    tr(
                      LocaleController.language.value,
                      'Barcha foto',
                      'Все фото',
                      'All photos',
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < colors.length; i++) ...[
          if (i != 0) const SizedBox(width: 10),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FeedbackCard(
            title: tr(
              lang,
              'Ilova sizga yoqdimi?',
              'Как вам приложение?',
              'How do you like the app?',
            ),
            asset: 'assets/icon/Ranking.svg',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FeedbackCard(
            title: tr(
              lang,
              'Qoʻllab-quvvatlashga yozish',
              'Написать в поддержку',
              'Write to support',
            ),
            asset: 'assets/icon/headphones.svg',
          ),
        ),
      ],
    );
  }
}

/// Small white card with a bottom-right illustration (FINAL design), same
/// pattern as the master home's mini cards.
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.title, required this.asset});

  final String title;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 122,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          SizedBox(
            width: 118,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                height: 1.25,
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

class _SpecialistCard extends StatelessWidget {
  const _SpecialistCard({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              lang,
              'Siz mutaxassismisiz?',
              'Вы специалист?',
              'Are you a specialist?',
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              lang,
              'FixLeo bilan mijozlar toping va daromad qiling',
              'Находите клиентов и зарабатывайте с FixLeo',
              'Find clients and earn with FixLeo',
            ),
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Human status line for the active-order card.
String _activeStatusLabel(AppLanguage lang, OrderSummary o) {
  switch (o.status) {
    case 'searching':
      return tr(lang, 'Usta qidirilmoqda', 'Ищем мастера', 'Finding a master');
    case 'assigned':
      return tr(lang, 'Usta tayinlandi', 'Мастер назначен', 'Master assigned');
    case 'on_the_way':
      return tr(lang, 'Usta yoʻlda', 'Мастер в пути', 'Master on the way');
    case 'arrived':
      return tr(lang, 'Usta yetib keldi', 'Мастер на месте', 'Master arrived');
    case 'work_done':
      return tr(
          lang, 'Ish bajarildi', 'Работа выполнена', 'Work completed');
    default:
      return tr(lang, 'Jarayonda', 'В процессе', 'In progress');
  }
}

/// Live "Активный заказ" card (FINAL) — bound to the client's real active
/// order; hidden when there is none. Tapping opens order tracking.
class _ActiveOrderCard extends StatefulWidget {
  const _ActiveOrderCard({required this.lang});

  final AppLanguage lang;

  @override
  State<_ActiveOrderCard> createState() => _ActiveOrderCardState();
}

class _ActiveOrderCardState extends State<_ActiveOrderCard> {
  final OrderService _service = OrderService();
  OrderSummary? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.list(status: 'active');
      if (mounted && items.isNotEmpty) {
        setState(() => _order = items.first);
      }
    } catch (_) {
      // No card on error — the home stays clean.
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) return const SizedBox.shrink();
    final lang = widget.lang;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: order.id),
          ),
        );
        if (mounted) _load();
      },
      child: _Card(
        radius: 40,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${tr(lang, 'Faol buyurtma', 'Активный заказ', 'Active order')} · ${order.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                _activeStatusLabel(lang, order),
                if (order.masterName != null) order.masterName!,
              ].join(' · '),
              style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563)),
            ),
          ],
        ),
      ),
    );
  }
}
