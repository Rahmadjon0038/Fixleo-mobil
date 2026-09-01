import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/core/notifications/native_call_service.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/categories/presentation/category_image.dart';
import 'package:fixleo/features/notifications/data/notification_service.dart';
import 'package:fixleo/features/notifications/presentation/notifications_screen.dart';
import 'package:fixleo/features/profile/presentation/my_addresses_screen.dart';
import 'package:fixleo/features/profile/presentation/profile_screen.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/data/chat_service.dart';
import 'package:fixleo/features/request/presentation/chats_list_screen.dart';
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
  final GlobalKey<_CategoriesCardState> _categoriesCardKey = GlobalKey();
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
    CallService.instance.connect('client');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(NativeCallService.instance.requestPermissions(context));
      }
    });
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
      if (!mounted) return;
      if (addresses.isEmpty) {
        setState(() => _defaultAddress = null);
        return;
      }
      final defaultAddress = addresses
          .where((item) => item.isDefault)
          .firstOrNull;
      setState(() => _defaultAddress = defaultAddress ?? addresses.first);
    } on Object {
      // The fallback city remains visible when the address book is unavailable.
    }
  }

  Future<void> _changeLocation() async {
    final saved = await Navigator.of(context).push<ClientAddress>(
      MaterialPageRoute(
        builder: (_) => MyAddressesScreen(
          orderService: _orders,
          selectionMode: true,
          selectedAddressId: _defaultAddress?.id,
        ),
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

  Future<void> _refreshHome() async {
    await Future.wait([
      CurrentUser.instance.refresh(),
      _loadDefaultAddress(),
      _loadActiveOrders(),
      _loadUnreadNotifications(),
      _loadUnreadChats(),
      if (_categoriesCardKey.currentState case final categories?)
        categories.refresh(),
    ]);
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
    return RefreshIndicator(
      color: AppColors.blue,
      backgroundColor: Colors.white,
      displacement: 64,
      onRefresh: _refreshHome,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _HomeHeader(
                    lang: lang,
                    unreadNotifications: _unreadNotifications,
                    onNotifications: _openNotifications,
                    onProfile: () => _setTab(4),
                  ),
                  const SizedBox(height: 14),
                  _GreetingCard(
                    lang: lang,
                    locationText: _defaultAddress?.addressText,
                    onChangeLocation: _changeLocation,
                  ),
                  if (_activeOrders.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ActiveOrdersBanner(
                      lang: lang,
                      count: _activeOrders.length,
                      onView: _openActiveOrders,
                    ),
                  ],
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickySearchDelegate(lang: lang, service: _categories),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 110),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoriesCard(
                    key: _categoriesCardKey,
                    lang: lang,
                    service: _categories,
                  ),
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
            ),
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
                        onTap: (visibleIndex) =>
                            _setTab(_realNavIndex(visibleIndex)),
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
    required this.onProfile,
  });

  final AppLanguage lang;
  final int unreadNotifications;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

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
          semanticLabel: tr(lang, 'Profil', 'Профиль', 'Profile'),
          onTap: onProfile,
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
  const _SearchHero({required this.lang, required this.service});

  final AppLanguage lang;
  final CategoryService service;

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RequestCategoryScreen(service: service, autofocusSearch: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = RequestCategoryScreen.searchHint(lang);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSearch(context),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.white.withValues(alpha: 0.82)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.blue,
                  size: 24,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14.5,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  const _StickySearchDelegate({required this.lang, required this.service});

  final AppLanguage lang;
  final CategoryService service;

  static const double _height = 74;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: overlapsContent
            ? AppColors.background.withValues(alpha: 0.96)
            : Colors.transparent,
        boxShadow: overlapsContent
            ? const [
                BoxShadow(
                  color: Color(0x0D0F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
        child: _SearchHero(lang: lang, service: service),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchDelegate oldDelegate) {
    return oldDelegate.lang != lang || oldDelegate.service != service;
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

class _CategoriesCard extends StatefulWidget {
  const _CategoriesCard({super.key, required this.lang, required this.service});

  final AppLanguage lang;
  final CategoryService service;

  @override
  State<_CategoriesCard> createState() => _CategoriesCardState();
}

class _CategoriesCardState extends State<_CategoriesCard> {
  List<CategoryGroup> _groups = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await widget.service.getGroups();
      if (!mounted) return;
      final visibleGroups = groups
          .where((group) => group.services.isNotEmpty)
          .toList(growable: false);
      setState(() {
        _groups = visibleGroups;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> refresh() => _load();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              widget.lang,
              'Sizga qanday yordam kerak?',
              'Какая помощь вам нужна?',
              'What do you need help with?',
            ),
            style: const TextStyle(
              fontSize: 17,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              widget.lang,
              'Kerakli xizmatni tanlang',
              'Выберите нужную услугу',
              'Choose the service you need',
            ),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_groups.isEmpty)
            SizedBox(
              height: 90,
              child: Center(
                child: Text(
                  tr(
                    widget.lang,
                    'Hozircha xizmatlar yo‘q',
                    'Пока нет доступных услуг',
                    'No services are available yet',
                  ),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            for (var index = 0; index < _groups.length; index++) ...[
              if (index != 0) const SizedBox(height: 18),
              _HomeCategoryRow(
                key: ValueKey('home-category-row-${_groups[index].id}'),
                group: _groups[index],
                language: widget.lang,
                onServiceTap: (service) => _openCategory(context, service),
              ),
            ],
          const SizedBox(height: 18),
          GlassButton(
            label: tr(
              widget.lang,
              'Barcha xizmatlar',
              'Все услуги',
              'All services',
            ),
            icon: Icons.grid_view_rounded,
            height: 50,
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

  void _openCategory(BuildContext context, Category category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewRequestScreen(
          categoryId: category.id,
          categoryName: category.localizedName(widget.lang),
        ),
      ),
    );
  }
}

class _HomeCategoryRow extends StatefulWidget {
  const _HomeCategoryRow({
    super.key,
    required this.group,
    required this.language,
    required this.onServiceTap,
  });

  final CategoryGroup group;
  final AppLanguage language;
  final ValueChanged<Category> onServiceTap;

  @override
  State<_HomeCategoryRow> createState() => _HomeCategoryRowState();
}

class _HomeCategoryRowState extends State<_HomeCategoryRow> {
  bool _loadImages = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('home-category-visibility-${widget.group.id}'),
      onVisibilityChanged: (info) {
        if (_loadImages || info.visibleFraction <= 0 || !mounted) return;
        setState(() => _loadImages = true);
      },
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.localizedTitle(widget.language),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 7.0;
                final cardWidth = (constraints.maxWidth - spacing * 2) / 3;
                return SizedBox(
                  height: 130,
                  child: ListView.separated(
                    key: PageStorageKey(
                      'home-category-list-${widget.group.id}',
                    ),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: widget.group.services.length,
                    separatorBuilder: (_, _) => const SizedBox(width: spacing),
                    itemBuilder: (context, index) {
                      final service = widget.group.services[index];
                      return _HomeServiceCard(
                        key: ValueKey('home-service-${service.id}'),
                        width: cardWidth,
                        service: service,
                        language: widget.language,
                        loadImage: _loadImages,
                        onTap: () => widget.onServiceTap(service),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeServiceCard extends StatelessWidget {
  const _HomeServiceCard({
    super.key,
    required this.width,
    required this.service,
    required this.language,
    required this.loadImage,
    required this.onTap,
  });

  final double width;
  final Category service;
  final AppLanguage language;
  final bool loadImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: service.localizedName(language),
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: width,
                  height: 86,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0E6EE)),
                    ),
                    child: CategoryImage(
                      category: service,
                      borderRadius: 13,
                      loadNetworkImage: loadImage,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    service.localizedName(language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
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
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
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
          ),
          // Bleeds to the true card corner (not inset by the text padding),
          // matching the Figma reference. Kept at the original 64px — a
          // bigger illustration reached up far enough to sit under the
          // three-line Uzbek support-card title ("Qo'llab-quvvatlashga
          // yozish"), so the text rendered as if cut off by the icon.
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
      return tr(lang, 'Jarayonda', 'В процессе', 'In progress');
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
