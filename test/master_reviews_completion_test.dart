import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_filters_screen.dart';
import 'package:fixleo/features/master/presentation/master_home_screen.dart';
import 'package:fixleo/features/master/presentation/master_order_completion_screen.dart';
import 'package:fixleo/features/master/presentation/master_offer_screen.dart';
import 'package:fixleo/features/master/presentation/master_offer_sent_screen.dart';
import 'package:fixleo/features/master/presentation/master_profile_screen.dart';
import 'package:fixleo/features/master/presentation/master_startup_router.dart';
import 'package:fixleo/features/master/presentation/master_verification_rejected_screen.dart';
import 'package:fixleo/features/notifications/data/notification_service.dart';
import 'package:fixleo/features/request/data/chat_service.dart' as chat;

class _FakeMasterMarketplaceService extends MasterMarketplaceService {
  @override
  Future<MasterOrderDetail> orderDetail(int id) async =>
      const MasterOrderDetail(
        id: 42,
        title: 'Real service',
        description: 'Completed work',
        status: 'arrived',
        addressText: 'Tashkent',
        price: 50000,
        priceType: 'fixed',
        timing: 'today',
        slotLabel: '12:00–15:00',
        canComplete: true,
      );
}

class _FakeFilterService extends MasterMarketplaceService {
  List<int> categoryIds = const [];
  int radiusKm = 0;
  String sort = '';

  @override
  Future<int> feedCount({
    List<int> categoryIds = const [],
    int radiusKm = 10,
    String sort = 'new',
  }) async {
    this.categoryIds = categoryIds;
    this.radiusKm = radiusKm;
    this.sort = sort;
    return 7;
  }
}

class _FakeMasterNavigationService extends MasterMarketplaceService {
  int feedCalls = 0;

  @override
  Future<List<FeedItem>> feed({
    List<int> categoryIds = const [],
    int radiusKm = 10,
    String sort = 'new',
  }) async {
    feedCalls++;
    return const [];
  }

  @override
  Future<List<MasterOrder>> orders({String status = 'current'}) async =>
      const [];

  @override
  Future<MasterReviews> reviews({int page = 1}) async => const MasterReviews();
}

class _FakeMasterProfileService extends MasterService {
  @override
  Future<Master> me() async => const Master(
    id: '#M-1',
    phone: '+998901234567',
    status: MasterStatus.active,
    verificationStatus: VerificationStatus.approved,
  );
}

class _PendingMasterProfileService extends MasterService {
  @override
  Future<Master> me() async => const Master(
    id: '#M-2',
    phone: '+998909999999',
    status: MasterStatus.unverified,
    verificationStatus: VerificationStatus.pending,
  );
}

class _RejectedMasterProfileService extends MasterService {
  @override
  Future<Master> me() async => const Master(
    id: '#M-3',
    phone: '+998908888888',
    name: 'Rejected Master',
    city: 'Tashkent',
    experienceYears: 4,
    status: MasterStatus.unverified,
    verificationStatus: VerificationStatus.rejected,
    rejectionReason: 'Passport photo is blurry',
  );
}

class _FakeMasterNotificationService extends NotificationService {
  _FakeMasterNotificationService() : super(kind: 'master');

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async =>
      const [];
}

class _FakeMasterChatService extends chat.ChatService {
  _FakeMasterChatService() : super(kind: 'master');

  @override
  Future<List<chat.Conversation>> conversations() async => const [
    chat.Conversation(
      id: 21,
      orderId: 42,
      orderTitle: 'Real service',
      peerName: 'Client',
      unreadCount: 4,
    ),
  ];
}

class _FilterHarness extends StatefulWidget {
  const _FilterHarness({required this.service});

  final MasterMarketplaceService service;

  @override
  State<_FilterHarness> createState() => _FilterHarnessState();
}

class _FilterHarnessState extends State<_FilterHarness> {
  String result = 'none';

  Future<void> _open() async {
    final filters = await Navigator.of(context).push<MasterFeedFilters>(
      MaterialPageRoute(
        builder: (_) => MasterFiltersScreen(
          service: widget.service,
          categories: const [
            Category(id: 5, name: 'Plumbing QA'),
            Category(id: 6, name: 'Electrical QA'),
          ],
        ),
      ),
    );
    if (filters != null && mounted) {
      setState(() {
        result =
            '${filters.categoryIds.join(',')}|${filters.radiusKm}|${filters.sort}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(result),
          TextButton(onPressed: _open, child: const Text('Open filters')),
        ],
      ),
    );
  }
}

void main() {
  test('master reviews parse real items and aggregate histogram', () {
    final result = MasterReviews.fromJson({
      'items': [
        {
          'id': 7,
          'rating': 5,
          'text': 'Real feedback',
          'clientName': 'Ali A.',
          'tags': ['quality'],
        },
      ],
      'aggregate': {
        'ratingAvg': 5,
        'ratingCount': 1,
        'ratingHist': {'5': 1},
      },
    });

    expect(result.ratingAvg, 5);
    expect(result.ratingCount, 1);
    expect(result.ratingHist[5], 1);
    expect(result.items.single.clientName, 'Ali A.');
    expect(result.items.single.text, 'Real feedback');
  });

  testWidgets('completion screen starts without default photos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MasterOrderCompletionScreen(
          orderId: 42,
          service: _FakeMasterMarketplaceService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Real service'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
  });

  testWidgets(
    'sent offer stays on confirmation instead of opening work status',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MasterOfferSentScreen()));

      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MasterOfferSentScreen), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    },
  );

  testWidgets('offer price is grouped by thousands while typing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MasterOfferScreen(orderId: 42)),
    );

    final priceField = find.byType(TextField).first;
    await tester.enterText(priceField, '200000000');
    await tester.pump();

    expect(
      tester.widget<TextField>(priceField).controller?.text,
      '200 000 000',
    );
  });

  testWidgets('master filter returns real categories, radius and sort', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);
    final service = _FakeFilterService();

    await tester.pumpWidget(
      MaterialApp(home: _FilterHarness(service: service)),
    );
    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();

    expect(service.categoryIds, [5, 6]);
    await tester.tap(find.text('Electrical QA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Up to 3 km'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Higher budget'));
    await tester.pumpAndSettle();

    expect(service.categoryIds, [5]);
    expect(service.radiusKm, 3);
    expect(service.sort, 'budget');
    await tester.tap(find.text('Show 7 requests'));
    await tester.pumpAndSettle();

    expect(find.text('5|3|budget'), findsOneWidget);
  });

  testWidgets('master profile stays scrollable on a keyboard-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: MasterProfileScreen()));
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -220),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('master onboarding cannot continue without a profile photo', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);

    await tester.pumpWidget(const MaterialApp(home: MasterProfileScreen()));
    await tester.tap(find.text('Save and continue'));
    await tester.pump();

    expect(find.text('Choose a profile photo'), findsOneWidget);
  });

  testWidgets('pending master cannot enter dashboard or profile tabs', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);

    await tester.pumpWidget(
      MaterialApp(
        home: MasterHomeScreen(masterService: _PendingMasterProfileService()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Documents under review'), findsOneWidget);
    expect(find.byType(LiquidGlassNavBar), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Documents under review'), findsOneWidget);
    expect(find.text('Profile created!'), findsNothing);
  });

  testWidgets(
    'rejected master sees the rejection screen and can correct data',
    (tester) async {
      LocaleController.language.value = AppLanguage.en;
      addTearDown(() => LocaleController.language.value = AppLanguage.ru);

      await tester.pumpWidget(
        MaterialApp(
          home: MasterHomeScreen(
            masterService: _RejectedMasterProfileService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Verification was not passed'), findsOneWidget);
      expect(find.text('Moderator reason'), findsOneWidget);
      expect(find.textContaining('Passport photo is blurry'), findsOneWidget);
      expect(find.byType(LiquidGlassNavBar), findsNothing);

      await tester.tap(find.text('Correct details'));
      await tester.pumpAndSettle();

      expect(find.text('Registration'), findsOneWidget);
      expect(find.text('Rejected Master'), findsOneWidget);
      expect(find.text('Tashkent'), findsOneWidget);
    },
  );

  test('returning rejected master resumes on the rejection screen', () async {
    final service = _RejectedMasterProfileService();
    final master = await service.me();

    final screen = await resolveMasterStartupScreen(service, master);

    expect(screen, isA<MasterVerificationRejectedScreen>());
  });

  testWidgets('master bottom tabs preserve the selected orders segment', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final marketplace = _FakeMasterNavigationService();
    await tester.pumpWidget(
      MaterialApp(
        home: MasterHomeScreen(
          marketplaceService: marketplace,
          masterService: _FakeMasterProfileService(),
          notificationService: _FakeMasterNotificationService(),
          chatService: _FakeMasterChatService(),
          ordersService: marketplace,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<LiquidGlassNavBar>(find.byType(LiquidGlassNavBar))
          .items[2]
          .badgeCount,
      4,
    );
    await tester.tap(find.text('Chats'));
    await tester.pump();
    // One top-level title plus the bottom-tab label; no nested duplicate title.
    expect(find.text('Chats'), findsNWidgets(2));
    await tester.tap(find.text('Requests'));
    await tester.pump();

    await tester.tap(find.text('Orders'));
    await tester.pump();
    await tester.tap(find.text('Reviews'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Reviews')).style?.fontWeight,
      FontWeight.w700,
    );

    await tester.tap(find.text('Requests'));
    await tester.pump();
    expect(marketplace.feedCalls, greaterThanOrEqualTo(2));
    await tester.tap(find.text('Orders'));
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Reviews')).style?.fontWeight,
      FontWeight.w700,
    );

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.tap(find.text('Work history'));
    await tester.pump();

    expect(
      tester
          .widget<LiquidGlassNavBar>(find.byType(LiquidGlassNavBar))
          .currentIndex,
      1,
    );
    expect(
      tester.widget<Text>(find.text('History')).style?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('work history opens History even before Orders was visited', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final marketplace = _FakeMasterNavigationService();
    await tester.pumpWidget(
      MaterialApp(
        home: MasterHomeScreen(
          marketplaceService: marketplace,
          masterService: _FakeMasterProfileService(),
          notificationService: _FakeMasterNotificationService(),
          chatService: _FakeMasterChatService(),
          ordersService: marketplace,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.tap(find.text('Work history'));
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('History')).style?.fontWeight,
      FontWeight.w700,
    );
  });
}
