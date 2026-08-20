import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/app.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/core/realtime/master_realtime_service.dart';
import 'package:fixleo/features/master/presentation/master_chats_screen.dart';
import 'package:fixleo/features/master/presentation/master_filters_screen.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/master/presentation/master_orders_screen.dart';
import 'package:fixleo/features/master/presentation/master_profile_tab_screen.dart';
import 'package:fixleo/features/master/presentation/master_verification_screen.dart';
import 'package:fixleo/features/master/presentation/master_verification_rejected_screen.dart';
import 'package:fixleo/features/master/presentation/master_wallet_screen.dart';
import 'package:fixleo/features/master/presentation/master_request_detail_screen.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_work_zone_screen.dart';
import 'package:fixleo/features/notifications/data/notification_service.dart';
import 'package:fixleo/features/notifications/presentation/notifications_screen.dart';
import 'package:fixleo/features/request/data/chat_service.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';

/// "12 мин назад"-style relative label shown on feed cards (FINAL design).
String _timeAgo(AppLanguage lang, DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) {
    return tr(lang, 'hozirgina', 'только что', 'just now');
  }
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return tr(lang, '$m daqiqa oldin', '$m мин назад', '$m min ago');
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return tr(lang, '$h soat oldin', '$h ч назад', '$h h ago');
  }
  final d = diff.inDays;
  return tr(lang, '$d kun oldin', '$d дн назад', '$d d ago');
}

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
    required this.timing,
    this.slotLabel,
    this.scheduledDate,
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
  final String timing;
  final String? slotLabel;
  final String? scheduledDate;

  String category(AppLanguage lang) =>
      tr(lang, categoryUz, categoryRu, categoryEn);
  String time(AppLanguage lang) => tr(lang, timeUz, timeRu, timeEn);
  String text(AppLanguage lang) => tr(lang, textUz, textRu, textEn);
  String location(AppLanguage lang) =>
      tr(lang, locationUz, locationRu, locationEn);
  String schedule(AppLanguage lang) => orderTimingLabel(
    lang,
    timing: timing,
    scheduledDate: scheduledDate,
    slotLabel: slotLabel,
  );
}

/// Access gate for every entry into the master dashboard.
///
/// Even if a stale route or a temporary bootstrap error tries to open home, the
/// real profile is checked first and no dashboard/profile tab is mounted until
/// the backend confirms the master is approved.
class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({
    super.key,
    this.marketplaceService,
    this.masterService,
    this.notificationService,
    this.chatService,
    this.ordersService,
    this.initialMaster,
  });

  final MasterMarketplaceService? marketplaceService;
  final MasterService? masterService;
  final NotificationService? notificationService;
  final ChatService? chatService;
  final MasterMarketplaceService? ordersService;
  final Master? initialMaster;

  @override
  State<MasterHomeScreen> createState() => _MasterHomeAccessGateState();
}

class _MasterHomeAccessGateState extends State<MasterHomeScreen> {
  late final MasterService _masterService =
      widget.masterService ?? MasterService();
  late Future<Master> _profileFuture = _loadProfile();

  Future<Master> _loadProfile() async {
    return widget.initialMaster ?? _masterService.me();
  }

  void _retry() {
    setState(() => _profileFuture = _masterService.me());
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return FutureBuilder<Master>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final master = snapshot.data;
        if (master != null) {
          if (master.verificationStatus == VerificationStatus.rejected) {
            return MasterVerificationRejectedScreen(
              rejectionReason: master.rejectionReason,
              rejectionReasons: master.rejectionReasons,
              masterService: _masterService,
            );
          }
          if (master.verificationStatus != VerificationStatus.approved) {
            return const MasterVerificationScreen(submitOnOpen: false);
          }
          return _ApprovedMasterHomeScreen(
            marketplaceService: widget.marketplaceService,
            masterService: _masterService,
            notificationService: widget.notificationService,
            chatService: widget.chatService,
            ordersService: widget.ordersService,
          );
        }

        if (snapshot.hasError) {
          return BrandedScaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 44,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        lang,
                        'Usta holatini tekshirib bo‘lmadi',
                        'Не удалось проверить статус мастера',
                        'Could not verify the master status',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      label: tr(lang, 'Qayta urinish', 'Повторить', 'Retry'),
                      onPressed: _retry,
                      height: 48,
                      expand: false,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const BrandedScaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

/// Approved master dashboard — nearby requests plus the shared bottom tabs.
class _ApprovedMasterHomeScreen extends StatefulWidget {
  const _ApprovedMasterHomeScreen({
    this.marketplaceService,
    this.masterService,
    this.notificationService,
    this.chatService,
    this.ordersService,
  });

  final MasterMarketplaceService? marketplaceService;
  final MasterService? masterService;
  final NotificationService? notificationService;
  final ChatService? chatService;
  final MasterMarketplaceService? ordersService;

  @override
  State<_ApprovedMasterHomeScreen> createState() =>
      _ApprovedMasterHomeScreenState();
}

class _ApprovedMasterHomeScreenState extends State<_ApprovedMasterHomeScreen>
    with WidgetsBindingObserver {
  late final MasterMarketplaceService _market =
      widget.marketplaceService ?? MasterMarketplaceService();
  late final MasterService _masterService =
      widget.masterService ?? MasterService();
  final MasterRealtimeService _realtime = MasterRealtimeService();
  late final NotificationService _notifications =
      widget.notificationService ?? NotificationService(kind: 'master');
  late final ChatService _chats =
      widget.chatService ?? ChatService(kind: 'master');
  List<FeedItem> _feedItems = const [];
  bool _feedLoading = true;
  String _query = '';
  Master? _masterProfile;
  MasterFeedFilters _feedFilters = const MasterFeedFilters();
  int _feedRequest = 0;
  int _unreadNotifications = 0;
  int _unreadChats = 0;
  final Set<int> _visitedTabs = {0};
  StreamSubscription<int>? _conversationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CurrentUser.instance.refresh();
    _loadMasterProfile();
    _loadFeed();
    _loadUnreadNotifications();
    _loadUnreadChats();
    _conversationSubscription = AppPresenceService.instance.conversationUpdates
        .listen((_) => unawaited(_loadUnreadChats()));
    // Voice-call signalling app-wide: an incoming call now rings on any screen,
    // not only inside a chat.
    CallService.instance.connect('master', onIncoming: showIncomingCallUi);
    // Live feed: a new nearby order (or a cancellation) refreshes the list
    // without requiring pull-to-refresh.
    _realtime.connect(
      onUpdate: (_) {},
      onNewOrderNearby: (_) => _loadFeed(),
      onOrderCancelled: (_) => _loadFeed(),
      onNotification: (_) => _loadUnreadNotifications(),
    );
  }

  Future<void> _loadMasterProfile() async {
    try {
      final profile = await _masterService.me();
      if (mounted) setState(() => _masterProfile = profile);
    } on Object {
      // Keep the fallback city visible when profile refresh fails.
    }
  }

  Future<void> _changeWorkZone() async {
    try {
      final profile = _masterProfile ?? await _masterService.me();
      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MasterWorkZoneScreen(
            isEditing: true,
            initialLatitude: profile.latitude,
            initialLongitude: profile.longitude,
            initialRadiusKm: profile.workRadiusKm,
          ),
        ),
      );
      if (changed == true) {
        await Future.wait([_loadMasterProfile(), _loadFeed()]);
      }
    } on Object {
      if (!mounted) return;
      final lang = LocaleController.language.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Lokatsiyani ochib boʻlmadi',
              'Не удалось открыть локацию',
              'Could not open location',
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtime.disconnect();
    unawaited(_conversationSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_loadFeed());
    unawaited(_loadUnreadNotifications());
    unawaited(_loadUnreadChats());
  }

  Future<void> _loadFeed() async {
    final request = ++_feedRequest;
    final filters = _feedFilters;
    if (mounted && !_feedLoading) setState(() => _feedLoading = true);
    try {
      final items = await _market.feed(
        categoryIds: filters.categoryIds,
        radiusKm: filters.radiusKm,
        sort: filters.sort,
      );
      if (mounted && request == _feedRequest) {
        setState(() {
          _feedItems = items;
          _feedLoading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _feedRequest) {
        setState(() => _feedLoading = false);
      }
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final items = await _notifications.list(unreadOnly: true);
      if (mounted) setState(() => _unreadNotifications = items.length);
    } on Object {
      // Keep the last known count while the network is temporarily unavailable.
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
      // Keep the last known count while the network is temporarily unavailable.
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
            NotificationsScreen(kind: 'master', service: _notifications),
      ),
    );
    if (mounted) await _loadUnreadNotifications();
  }

  _Request _asRequest(FeedItem f) {
    final km = f.distanceKm.toStringAsFixed(1);
    String loc(String unit) =>
        [if (f.district != null) f.district!, '$km $unit'].join(' · ');
    return _Request(
      categoryUz: f.categoryName,
      categoryRu: f.categoryName,
      categoryEn: f.categoryName,
      icon: Icons.build_outlined,
      timeUz: _timeAgo(AppLanguage.uz, f.createdAt),
      timeRu: _timeAgo(AppLanguage.ru, f.createdAt),
      timeEn: _timeAgo(AppLanguage.en, f.createdAt),
      textUz: f.description,
      textRu: f.description,
      textEn: f.description,
      locationUz: loc('km'),
      locationRu: loc('км'),
      locationEn: loc('km'),
      timing: f.timing,
      slotLabel: f.slotLabel,
      scheduledDate: f.scheduledDate,
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

  int _navIndex = 0;
  int _ordersRefreshSignal = 0;
  int _ordersSegmentSignal = 0;
  int _ordersTargetSegment = 0;

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
      if (index == 2) unawaited(_loadUnreadChats());
      return;
    }
    setState(() {
      _visitedTabs.add(index);
      _navIndex = index;
      if (index == 1) _ordersRefreshSignal++;
    });
    if (index == 0) {
      unawaited(_loadFeed());
      unawaited(_loadUnreadNotifications());
    }
    unawaited(_loadUnreadChats());
  }

  void _goBackTab() {
    if (_navIndex != 0) {
      _setTab(0);
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _openOrderHistory() {
    setState(() {
      _visitedTabs.add(1);
      _navIndex = 1;
      _ordersRefreshSignal++;
      _ordersTargetSegment = 1;
      _ordersSegmentSignal++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showBrand = shouldShowBrandBar();
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
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        if (showBrand) const Center(child: BrandBar()),
                        const SizedBox(height: 8),
                        _header(lang, navItems),
                        Expanded(
                          // Keep every visited top-level tab mounted while
                          // switching. Stateful tabs must not lose their selected
                          // segment, scroll position, or already loaded data.
                          child: IndexedStack(
                            index: _navIndex,
                            children: [
                              _feed(),
                              _tabWhenVisited(
                                1,
                                MasterOrdersScreen(
                                  service: widget.ordersService,
                                  refreshSignal: _ordersRefreshSignal,
                                  segmentSignal: _ordersSegmentSignal,
                                  targetSegment: _ordersTargetSegment,
                                ),
                              ),
                              _tabWhenVisited(
                                2,
                                MasterChatsScreen(
                                  service: _chats,
                                  onUnreadChanged: _setUnreadChats,
                                ),
                              ),
                              _tabWhenVisited(3, const MasterWalletScreen()),
                              _tabWhenVisited(
                                4,
                                MasterProfileTabScreen(
                                  onNotificationsChanged:
                                      _loadUnreadNotifications,
                                  onOpenWorkHistory: _openOrderHistory,
                                  service: _masterService,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _tabWhenVisited(int index, Widget child) {
    return _visitedTabs.contains(index) ? child : const SizedBox.shrink();
  }

  /// Header row. On the feed tab it matches FINAL: FixLeo brand pill on the
  /// left, filter button on the right (no back). Other tabs keep the
  /// back · title pill layout.
  Widget _header(AppLanguage lang, List<LiquidGlassNavItem> navItems) {
    if (_navIndex == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/logo.svg', width: 26, height: 26),
                    const SizedBox(width: 8),
                    const Text(
                      'FixLeo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GlassIconButton(
                onTap: _openNotifications,
                badgeCount: _unreadNotifications,
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                onTap: () async {
                  final filters = await Navigator.of(context)
                      .push<MasterFeedFilters>(
                        MaterialPageRoute(
                          builder: (_) => MasterFiltersScreen(
                            initial: _feedFilters,
                            categories: _masterProfile?.categories ?? const [],
                          ),
                        ),
                      );
                  if (filters != null && mounted) {
                    setState(() => _feedFilters = filters);
                    await _loadFeed();
                  }
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
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
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
              child: Text(
                switch (_navIndex) {
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
              child: GlassIconButton(
                onTap: _goBackTab,
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Feed items narrowed by the hero search query (description or category).
  List<FeedItem> get _visibleFeedItems {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _feedItems;
    return _feedItems
        .where(
          (f) =>
              f.description.toLowerCase().contains(q) ||
              f.categoryName.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  /// Dark hero card — "Найдём клиентов под любую услугу" + search (FINAL).
  Widget _searchHero(AppLanguage lang) {
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
              'Har qanday xizmat uchun mijoz\ntopamiz',
              'Найдём клиентов под любую\nуслугу',
              'We’ll find clients for any service',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.navy,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: tr(
                          lang,
                          'Zayavka yoki xizmat',
                          'Заявка или услуга',
                          'Request or service',
                        ),
                        hintStyle: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.search, color: AppColors.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feed() {
    final visible = _visibleFeedItems;
    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _greeting(),
          const SizedBox(height: 10),
          _searchHero(LocaleController.language.value),
          const SizedBox(height: 10),
          if (_feedLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  _query.trim().isNotEmpty
                      ? tr(
                          LocaleController.language.value,
                          'Hech narsa topilmadi',
                          'Ничего не найдено',
                          'Nothing found',
                        )
                      : tr(
                          LocaleController.language.value,
                          'Hozircha zayavkalar yoʻq',
                          'Пока нет заявок',
                          'No requests yet',
                        ),
                  style: const TextStyle(color: Color(0xFF8D96A4)),
                ),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              _RequestCard(
                request: _asRequest(visible[i]),
                onRespond: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MasterRequestDetailScreen(orderId: visible[i].id),
                    ),
                  );
                  if (mounted) _loadFeed();
                },
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
      ),
    );
  }

  /// Greeting + location + "change location" pill.
  Widget _greeting() {
    final lang = LocaleController.language.value;
    return GlassContainer(
      borderRadius: 296,
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      tintOpacityTop: 0.92,
      tintOpacityBottom: 0.72,
      borderOpacity: 0.8,
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
                          : tr(
                              lang,
                              'Xayrli kun, $name!',
                              'Добрый день, $name!',
                              'Good day, $name!',
                            ),
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
                    Expanded(
                      child: Text(
                        [
                          _masterProfile?.city ??
                              tr(
                                lang,
                                'Lokatsiya tanlanmagan',
                                'Локация не выбрана',
                                'Location not selected',
                              ),
                          if (_masterProfile?.workRadiusKm != null)
                            '${_masterProfile!.workRadiusKm} km',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
          GestureDetector(
            onTap: _changeWorkZone,
            child: GlassContainer.tinted(
              borderRadius: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
        ],
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
    return GlassContainer.lite(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
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
              Icon(
                Icons.schedule,
                size: 15,
                color: request.timing == 'asap'
                    ? AppColors.blue
                    : const Color(0xFF8D96A4),
              ),
              const SizedBox(width: 5),
              Text(
                request.schedule(LocaleController.language.value),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: request.timing == 'asap'
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: request.timing == 'asap'
                      ? AppColors.blue
                      : const Color(0xFF8D96A4),
                ),
              ),
            ],
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
          GlassButton(
            label: tr(
              LocaleController.language.value,
              'Javob berish',
              'Откликнуться',
              'Respond',
            ),
            onPressed: onRespond,
            height: 46,
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
    return GlassContainer(
      height: 122,
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
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
          ),
          // Bleeds to the true card corner (not inset by the text's own
          // padding) so the icon has room to sit clear of a three-line
          // title instead of overlapping its last line — same fix as
          // home_screen.dart's _FeedbackCard.
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
