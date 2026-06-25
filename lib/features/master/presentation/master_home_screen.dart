import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/liquid_glass_nav_bar.dart';
import 'package:fixleo/features/master/presentation/master_filters_screen.dart';
import 'package:fixleo/features/master/presentation/master_request_detail_screen.dart';

/// A nearby job request shown in the master feed.
class _Request {
  const _Request({
    required this.category,
    required this.icon,
    required this.time,
    required this.text,
    required this.location,
  });

  final String category;
  final IconData icon;
  final String time;
  final String text;
  final String location;
}

/// Master dashboard — "nearby requests" feed with the shared liquid-glass
/// bottom navigation. Only the requests tab has content for now.
class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  static const _navItems = [
    LiquidGlassNavItem('Buyurtmalar', 'assets/icon/Home.svg'),
    LiquidGlassNavItem('Zakazlar', 'assets/icon/History.svg'),
    LiquidGlassNavItem('Chatlar', 'assets/icon/chat.svg'),
    LiquidGlassNavItem('Hamyon', 'assets/icon/wallet.svg'),
    LiquidGlassNavItem('Profil', 'assets/icon/usericon.svg'),
  ];

  static const _requests = [
    _Request(
      category: 'Santexnika',
      icon: Icons.water_drop_outlined,
      time: '12 daqiqa oldin',
      text: 'Oshxonada smesitel oqyapti, kartrij almashtirish kerak',
      location: 'Yunusobod · 2.4 km',
    ),
    _Request(
      category: 'Elektrika',
      icon: Icons.bolt_outlined,
      time: '12 daqiqa oldin',
      text: 'Rozetka ishlamayapti, uchqun chiqyapti',
      location: 'Yunusobod · 2.4 km',
    ),
  ];

  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 8),
                const Center(child: BrandBar()),
                const SizedBox(height: 8),
                _header(),
                Expanded(
                  child: _navIndex == 0
                      ? _feed()
                      : const _ComingSoon(),
                ),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: LiquidGlassNavBar(
                items: _navItems,
                currentIndex: _navIndex,
                onTap: (i) => setState(() => _navIndex = i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Back · title pill · filter row.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _Pill(
              child: Text(
                'Yoningizdagi buyurtmalar',
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
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.navy,
                ),
              ),
            ),
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
        for (final r in _requests) ...[
          _RequestCard(
            request: r,
            onRespond: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MasterRequestDetailScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: const [
            Expanded(
              child: _MiniCard(
                title: 'Ilova qanday?',
                asset: 'assets/icon/Ranking.svg',
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _MiniCard(
                title: 'Qoʻllab-quvvatlashga yozish',
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
                const Text(
                  'Xayrli kun, Arslan!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: const [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.navy,
                    ),
                    SizedBox(width: 2),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Text(
              'Lokatsiyani oʻzgartirish',
              style: TextStyle(
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
                      request.category,
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
                request.time,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8D96A4)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.text,
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
                request.location,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8D96A4),
                ),
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
  const _MiniCard({required this.title, required this.asset});

  final String title;
  final String asset;

  @override
  Widget build(BuildContext context) {
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
              title,
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
    return Center(
      child: Text(
        'Tez orada',
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
