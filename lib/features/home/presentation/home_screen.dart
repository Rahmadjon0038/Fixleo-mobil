import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/profile/presentation/profile_screen.dart';
import 'package:fixleo/features/request/presentation/my_orders_screen.dart';
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
  Widget build(BuildContext context) {
    return BrandedScaffold(
      showBrand: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Center(child: BrandBar()),
                  SizedBox(height: 12),
                  _HomeHeader(),
                  SizedBox(height: 14),
                  _GreetingCard(),
                  SizedBox(height: 14),
                  _SearchHero(),
                  SizedBox(height: 14),
                  _CategoriesCard(),
                  SizedBox(height: 14),
                  _PhotosCard(),
                  SizedBox(height: 14),
                  _FeedbackRow(),
                  SizedBox(height: 14),
                  _SpecialistCard(),
                  SizedBox(height: 14),
                  _ActiveOrderCard(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: _LiquidGlassNavBar(
              currentIndex: _navIndex,
              onTap: (i) {
                setState(() => _navIndex = i);
                // "Buyurtmalar" tab → orders list; "Profil" tab → profile.
                if (i == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                  );
                } else if (i == 3) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  );
                } else if (i == 4) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                }
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
    this.badge,
    this.iconSize = 22,
  });

  final String asset;
  final String? badge;
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
        if (badge != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                badge!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

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
          asset: 'assets/icon/notificationicon.svg',
          badge: '21',
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
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xayrli kun, Arslan!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.navy),
                    SizedBox(width: 4),
                    Text(
                      'Yashnobod, Toshkent',
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
            child: const Text(
              'Manzilni oʻzgartirish',
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
  const _SearchHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Har qanday vazifa uchun ishonchli\nusta topamiz',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
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
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Mutaxassis yoki xizmat',
                        hintStyle: TextStyle(
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

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard();

  static const _items = [
    _Category('Santexnika'),
    _Category('Elektrika'),
    _Category('Tozalash'),
    _Category('Maishiy texnika'),
    _Category('Boʻyash'),
    _Category('Yigʻish'),
  ];

  @override
  Widget build(BuildContext context) {
    final row1 = _items.take(3).toList();
    final row2 = _items.skip(3).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bizning Fix-erlar',
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
              label: const Text(
                'Vazifa soʻrash',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/icon/Waterdrop.svg',
              width: 22,
              height: 22,
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
          const Text(
            'Ustalar fotosi',
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
                  child: const Text(
                    'Barcha foto',
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
  const _FeedbackRow();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(child: _FeedbackCard(title: 'Ilova sizga\nyoqdimi?')),
          SizedBox(width: 12),
          Expanded(child: _FeedbackCard(title: 'Qoʻllab-quvvatlashga\nyozish')),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
          height: 1.25,
        ),
      ),
    );
  }
}

class _SpecialistCard extends StatelessWidget {
  const _SpecialistCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Siz mutaxassismisiz?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'FixLeo bilan mijozlar toping va daromad qiling',
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

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
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
              const Expanded(
                child: Text(
                  'Faol buyurtma · Smesitel taʼmiri',
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
          const Text(
            'Usta yoʻlda · ~15 daqiqa',
            style: TextStyle(fontSize: 10, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.asset);
  final String label;
  final String asset;
}

/// Floating iOS "liquid glass" bottom navigation bar — translucent,
/// blurred, with a bright edge highlight like a water droplet.
class _LiquidGlassNavBar extends StatelessWidget {
  const _LiquidGlassNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem('Asosiy', 'assets/icon/Home.svg'),
    _NavItem('Buyurtmalar', 'assets/icon/History.svg'),
    _NavItem('Chatlar', 'assets/icon/chat.svg'),
    _NavItem('Hamyon', 'assets/icon/wallet.svg'),
    _NavItem('Profil', 'assets/icon/usericon.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        height: 80,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Glass background layer — the blur lives here, with NO
              // interactive children (avoids the macOS mouse_tracker bug).
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white.withValues(alpha: 0.65),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(36),
                  ),
                ),
              ),
              // Interactive layer — sits ON TOP of the blur, not inside it.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / _items.length;
                    void selectAt(double dx) {
                      final i = (dx / itemWidth).floor().clamp(
                        0,
                        _items.length - 1,
                      );
                      if (i != currentIndex) onTap(i);
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Tap a tab, or drag a finger across the bar and the
                      // selection follows and lands where you release.
                      onTapDown: (d) => selectAt(d.localPosition.dx),
                      onHorizontalDragStart: (d) =>
                          selectAt(d.localPosition.dx),
                      onHorizontalDragUpdate: (d) =>
                          selectAt(d.localPosition.dx),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Sliding "liquid" highlight — flows from one tab to
                          // the next as the selection changes.
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment((currentIndex - 2) / 2, 0),
                            child: FractionallySizedBox(
                              widthFactor: 1 / _items.length,
                              heightFactor: 1,
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0079EB,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < _items.length; i++)
                                Expanded(
                                  child: _NavButton(
                                    item: _items[i],
                                    active: i == currentIndex,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active});

  final _NavItem item;
  final bool active;

  static const _activeColor = Color(0xFF0079EB);

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 300);
    final color = active ? _activeColor : AppColors.navy;
    // Purely visual — tap/drag is handled by the parent gesture detector.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: active ? 1.12 : 1.0,
          duration: duration,
          curve: Curves.easeOutBack,
          child: SvgPicture.asset(
            item.asset,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: duration,
          curve: Curves.easeOut,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
          child: Text(item.label),
        ),
      ],
    );
  }
}
