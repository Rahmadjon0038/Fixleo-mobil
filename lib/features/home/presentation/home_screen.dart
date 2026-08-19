import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/app.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/notifications/data/notification_service.dart';
import 'package:fixleo/features/notifications/presentation/notifications_screen.dart';
import 'package:fixleo/features/profile/presentation/profile_screen.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/data/chat_service.dart';
import 'package:fixleo/features/request/presentation/chats_list_screen.dart';
import 'package:fixleo/features/request/presentation/address_screen.dart';
import 'package:fixleo/features/request/presentation/my_orders_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';
import 'package:fixleo/features/request/presentation/request_category_screen.dart';
import 'package:fixleo/features/wallet/presentation/wallet_screen.dart';
import 'package:fixleo/features/request/presentation/new_request_screen.dart';

/// Main home feed shown after a successful login. A single scrollable page
/// with a floating "liquid glass" bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.orderService,
    this.notificationService,
    this.categoryService,
    this.chatService,
  });

  /// Injectable for widget tests; production uses the shared API client.
  final OrderService? orderService;
  final NotificationService? notificationService;
  final CategoryService? categoryService;
  final ChatService? chatService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _navIndex = 0;
  final Set<int> _visitedTabs = {0};
  late final OrderService _orders;
  late final NotificationService _notifications;
  late final CategoryService _categories;
  late final ChatService _chats;
  ClientAddress? _defaultAddress;
  List<OrderSummary> _activeOrders = const [];
  int _unreadNotifications = 0;
  int _unreadChats = 0;
  StreamSubscription<int>? _conversationSubscription;

  @override
  void initState() {
    super.initState();
    _orders = widget.orderService ?? OrderService();
    _notifications =
        widget.notificationService ?? NotificationService(kind: 'client');
    _categories = widget.categoryService ?? CategoryService();
    _chats = widget.chatService ?? ChatService(kind: 'client');
    WidgetsBinding.instance.addObserver(this);
    // Load the real signed-in profile so the greeting shows the actual name.
    CurrentUser.instance.refresh();
    _loadDefaultAddress();
    _loadActiveOrders();
    _loadUnreadNotifications();
    _loadUnreadChats();
    _conversationSubscription = AppPresenceService.instance.conversationUpdates
        .listen((_) => unawaited(_loadUnreadChats()));
    // Voice-call signalling app-wide: an incoming call rings on any screen.
    CallService.instance.connect('client', onIncoming: showIncomingCallUi);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_loadActiveOrders());
    unawaited(_loadUnreadNotifications());
    unawaited(_loadUnreadChats());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_conversationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _loadDefaultAddress() async {
    try {
      final addresses = await _orders.addresses();
      if (!mounted || addresses.isEmpty) return;
      setState(() => _defaultAddress = addresses.first);
    } on Object {
      // The fallback city remains visible when the address book is unavailable.
    }
  }

  Future<void> _changeLocation() async {
    final saved = await Navigator.of(context).push<ClientAddress>(
      MaterialPageRoute(
        builder: (_) =>
            AddressScreen(isEditingHome: true, initialAddress: _defaultAddress),
      ),
    );
    if (saved != null && mounted) setState(() => _defaultAddress = saved);
  }

  Future<void> _loadActiveOrders() async {
    try {
      final items = await _orders.list(status: 'active');
      if (!mounted) return;
      setState(() => _activeOrders = items);
    } on Object {
      // Keep the last known state on a temporary network failure.
    }
  }

  void _openActiveOrders() => _setTab(1);

  Future<void> _loadUnreadNotifications() async {
    try {
      final items = await _notifications.list(unreadOnly: true);
      if (!mounted) return;
      setState(() => _unreadNotifications = items.length);
    } on Object {
      // Keep the last known badge count during a temporary network failure.
    }
  }

  Future<void> _loadUnreadChats() async {
    try {
      final conversations = await _chats.conversations();
      if (!mounted) return;
      setState(
        () => _unreadChats = conversations.fold(
          0,
          (total, item) => total + item.unreadCount,
        ),
      );
    } on Object {
      // Keep the last known badge count during a temporary network failure.
    }
  }

  void _setUnreadChats(int count) {
    if (!mounted || count == _unreadChats) return;
    setState(() => _unreadChats = count);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NotificationsScreen(kind: 'client', service: _notifications),
      ),
    );
    if (mounted) await _loadUnreadNotifications();
  }

  List<LiquidGlassNavItem> _navItems(AppLanguage lang) => [
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
      badgeCount: _unreadChats,
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

  /// Nav-item index of the Wallet tab — hidden entirely for a demo account
  /// (app-store/Play-Market review), which must never show money UI.
  static const _walletTabIndex = 3;

  /// Drops the Wallet item from the nav bar for a demo account, without
  /// touching `_navIndex`/`IndexedStack` (which stay in the real 5-tab index
  /// space everywhere else in this file).
  List<LiquidGlassNavItem> _visibleNavItems(List<LiquidGlassNavItem> all) {
    if (!CurrentUser.instance.isDemo) return all;
    return [
      for (var i = 0; i < all.length; i++)
        if (i != _walletTabIndex) all[i],
    ];
  }

  /// Real tab index -> the nav bar's displayed position (one slot short when
  /// Wallet is hidden).
  int _visibleNavIndex(int realIndex) {
    if (!CurrentUser.instance.isDemo) return realIndex;
    return realIndex > _walletTabIndex ? realIndex - 1 : realIndex;
  }

  /// The nav bar's displayed position -> real tab index (inverse of above).
  int _realNavIndex(int visibleIndex) {
    if (!CurrentUser.instance.isDemo) return visibleIndex;
    return visibleIndex >= _walletTabIndex ? visibleIndex + 1 : visibleIndex;
  }

  void _setTab(int index) {
    if (index == _navIndex) {
      if (index == 0) {
        unawaited(_loadActiveOrders());
        unawaited(_loadUnreadNotifications());
      }
      if (index == 2) unawaited(_loadUnreadChats());
      return;
    }
    setState(() {
      _visitedTabs.add(index);
      _navIndex = index;
    });
    if (index == 0) {
      unawaited(_loadActiveOrders());
      unawaited(_loadUnreadNotifications());
    }
    unawaited(_loadUnreadChats());
  }

  Widget _tabWhenVisited(int index, Widget child) {
    return _visitedTabs.contains(index) ? child : const SizedBox.shrink();
  }

  Widget _homeTab(AppLanguage lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BrandedScaffold previously supplied this top spacing. Keep the
          // home layout unchanged while the top-level tabs share one shell.
          const SizedBox(height: 44),
          _HomeHeader(
            lang: lang,
            unreadNotifications: _unreadNotifications,
            onNotifications: _openNotifications,
          ),
          const SizedBox(height: 14),
          _GreetingCard(
            lang: lang,
            locationText: _defaultAddress?.addressText,
            onChangeLocation: _changeLocation,
          ),
          const SizedBox(height: 14),
          if (_activeOrders.isNotEmpty) ...[
            _ActiveOrdersBanner(
              lang: lang,
              count: _activeOrders.length,
              onView: _openActiveOrders,
            ),
            const SizedBox(height: 14),
          ],
          _SearchHero(lang: lang),
          const SizedBox(height: 14),
          _CategoriesCard(lang: lang, service: _categories),
          const SizedBox(height: 14),
          const _PhotosCard(),
          const SizedBox(height: 14),
          _FeedbackRow(lang: lang),
          const SizedBox(height: 14),
          _SpecialistCard(lang: lang),
          const SizedBox(height: 14),
          _ActiveOrderCard(
            lang: lang,
            order: _activeOrders.isEmpty ? null : _activeOrders.first,
            onChanged: _loadActiveOrders,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.language,
      builder: (context, lang, _) {
        final navItems = _navItems(lang);
        return PopScope(
          canPop: _navIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _navIndex != 0) _setTab(0);
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: GlassBackground(
              child: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IndexedStack(
                        index: _navIndex,
                        children: [
                          _homeTab(lang),
                          _tabWhenVisited(
                            1,
                            MyOrdersScreen(embedded: true, service: _orders),
                          ),
                          _tabWhenVisited(
                            2,
                            LiveChatsScreen(
                              kind: 'client',
                              showBack: false,
                              service: _chats,
                              onUnreadChanged: _setUnreadChats,
                            ),
                          ),
                          _tabWhenVisited(
                            3,
                            const WalletScreen(embedded: true),
                          ),
                          _tabWhenVisited(
                            4,
                            const ProfileScreen(embedded: true),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: LiquidGlassNavBar(
                        items: _visibleNavItems(navItems),
                        currentIndex: _visibleNavIndex(_navIndex),
                        onTap: (visibleIndex) => _setTab(_realNavIndex(visibleIndex)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.lang,
    required this.unreadNotifications,
    required this.onNotifications,
  });

  final AppLanguage lang;
  final int unreadNotifications;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassContainer(
          borderRadius: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        GlassIconButton(
          size: 48,
          badgeCount: unreadNotifications,
          semanticLabel: tr(
            lang,
            'Bildirishnomalar',
            'Уведомления',
            'Notifications',
          ),
          onTap: onNotifications,
          child: SvgPicture.asset(
            'assets/icon/notificationicon.svg',
            width: 21,
            height: 21,
          ),
        ),
        const SizedBox(width: 12),
        GlassIconButton(
          size: 48,
          child: SvgPicture.asset(
            'assets/icon/usericon.svg',
            width: 21,
            height: 21,
          ),
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.lang,
    required this.locationText,
    required this.onChangeLocation,
  });

  final AppLanguage lang;
  final String? locationText;
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
                        : tr(
                            lang,
                            'Xayrli kun, $name!',
                            'Добрый день, $name!',
                            'Good day, $name!',
                          );
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
                    Expanded(
                      child: Text(
                        locationText ??
                            tr(
                              lang,
                              'Lokatsiya tanlanmagan',
                              'Локация не выбрана',
                              'Location not selected',
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChangeLocation,
            child: Container(
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

class _ActiveOrdersBanner extends StatelessWidget {
  const _ActiveOrdersBanner({
    required this.lang,
    required this.count,
    required this.onView,
  });

  final AppLanguage lang;
  final int count;
  final VoidCallback onView;

  String get _title {
    if (count == 1) {
      return tr(
        lang,
        'Sizda 1 ta faol buyurtma bor',
        'У вас 1 активный заказ',
        'You have 1 active order',
      );
    }
    return tr(
      lang,
      'Sizda $count ta faol buyurtma bor',
      'У вас активных заказов: $count',
      'You have $count active orders',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 23,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr(
                    lang,
                    'Jarayonni Buyurtmalar boʻlimida kuzating',
                    'Следите за ходом выполнения в разделе заказов',
                    'Track progress in the Orders section',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GlassButton(
            label: tr(lang, 'Koʻrish', 'Смотреть', 'View'),
            onPressed: onView,
            height: 40,
            expand: false,
          ),
        ],
      ),
    );
  }
}

class _Category {
  const _Category(this.label, {this.id});
  final String label;
  final int? id;
}

class _CategoriesCard extends StatefulWidget {
  const _CategoriesCard({required this.lang, required this.service});

  final AppLanguage lang;
  final CategoryService service;

  @override
  State<_CategoriesCard> createState() => _CategoriesCardState();
}

class _CategoriesCardState extends State<_CategoriesCard> {
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
      final categories = await widget.service.getAll();
      if (!mounted || categories.isEmpty) return;
      setState(() {
        _items = categories
            .map((c) => _Category(c.name, id: c.id))
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

    return GlassCard(
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
                  children: [
                    for (final c in row1)
                      _CategoryChip(
                        category: c,
                        onTap: () => _openCategory(context, c),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final c in row2)
                      _CategoryChip(
                        category: c,
                        onTap: () => _openCategory(context, c),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: tr(
              widget.lang,
              'Vazifa soʻrash',
              'Запросить задание',
              'Request a task',
            ),
            icon: Icons.add,
            height: 52,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RequestCategoryScreen(service: widget.service),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openCategory(BuildContext context, _Category category) {
    final id = category.id;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => id == null
            ? RequestCategoryScreen(service: widget.service)
            : NewRequestScreen(categoryId: id, categoryName: category.label),
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
  if (n.contains('крас') ||
      n.contains('boʻyash') ||
      n.contains("bo'yash") ||
      n.contains('paint')) {
    return Icons.format_paint_outlined;
  }
  if (n.contains('сбор') ||
      n.contains('мебел') ||
      n.contains('yigʻ') ||
      n.contains("yig'") ||
      n.contains('mebel')) {
    return Icons.chair_alt_outlined;
  }
  return Icons.handyman_outlined;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final _Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassContainer.lite(
          borderRadius: 24,
          padding: const EdgeInsets.all(14),
          // No drop shadow — these sit edge-to-edge in a scrolling row, and
          // the default soft shadow smears into a glow across the whole
          // row instead of reading as separate chips.
          shadow: false,
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
        ),
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
    return GlassCard(
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
    return GlassContainer(
      height: 122,
      borderRadius: 24,
      padding: const EdgeInsets.all(14),
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
    return GlassCard(
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
      return tr(lang, 'Ish bajarildi', 'Работа выполнена', 'Work completed');
    default:
      return tr(lang, 'Jarayonda', 'В процессе', 'In progress');
  }
}

/// Live "Активный заказ" card (FINAL) — bound to the first active order and
/// kept at the bottom as a compact shortcut. Tapping opens order tracking.
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.lang,
    required this.order,
    required this.onChanged,
  });

  final AppLanguage lang;
  final OrderSummary? order;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    if (order == null) return const SizedBox.shrink();
    final activeOrder = order!;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: activeOrder.id),
          ),
        );
        await onChanged();
      },
      child: GlassCard(
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
                    '${tr(lang, 'Faol buyurtma', 'Активный заказ', 'Active order')} · ${activeOrder.title}',
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
                _activeStatusLabel(lang, activeOrder),
                if (activeOrder.masterName != null) activeOrder.masterName!,
              ].join(' · '),
              style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563)),
            ),
          ],
        ),
      ),
    );
  }
}
