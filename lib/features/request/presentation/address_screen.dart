import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/time_urgency_screen.dart';

/// Step 3 of the "new request" flow — a real, draggable map where the user
/// pins the spot the master should come to. The map moves under a fixed
/// center marker, so wherever the map is dropped is the chosen address.
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  /// Tashkent center as a sensible starting point.
  static const _start = LatLng(41.311081, 69.279737);

  final _mapController = MapController();

  /// Whether the map is mid-drag (used to lift the pin a touch for feedback).
  bool _dragging = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    final moving = event is MapEventMove || event is MapEventFlingAnimation;
    if (moving != _dragging) {
      setState(() => _dragging = moving);
    }
  }

  void _recenter() => _mapController.move(_start, 15);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // The real, movable map fills the whole screen.
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _start,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 18,
              onMapEvent: _onMapEvent,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fixleo.app',
              ),
            ],
          ),

          // Fixed center pin — the map slides beneath it to pick a spot.
          // The lower dot is offset to rest exactly on the map's center
          // point, so the visible pin matches the picked coordinate.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -29),
                child: _CenterMarker(lifted: _dragging),
              ),
            ),
          ),

          // Top brand badge + "the map can be moved" hint.
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                const Center(child: BrandBar()),
                const SizedBox(height: 18),
                Text(
                  'Xaritani siljitish mumkin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    height: 24 / 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom sheet with the picked address and confirm button.
          Align(
            alignment: Alignment.bottomCenter,
            child: _AddressSheet(
              onBack: () => Navigator.of(context).maybePop(),
              onRecenter: _recenter,
              onConfirm: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TimeUrgencyScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The white pin marker that floats over the map center.
class _CenterMarker extends StatelessWidget {
  const _CenterMarker({required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSlide(
          duration: const Duration(milliseconds: 150),
          offset: Offset(0, lifted ? -0.18 : 0),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              size: 24,
              color: AppColors.blue,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Small dot marking the precise point on the ground.
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.blue, width: 3),
          ),
        ),
      ],
    );
  }
}

/// Round frosted-glass map control (back / locate buttons).
class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
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
            // Soft ambient drop shadow.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            // Tight contact shadow for a crisper, raised edge.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Glossy top-left → bottom-right white sheen.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.80),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 22, color: AppColors.navy),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom card: floating map controls + the picked-address sheet.
class _AddressSheet extends StatelessWidget {
  const _AddressSheet({
    required this.onBack,
    required this.onRecenter,
    required this.onConfirm,
  });

  final VoidCallback onBack;
  final VoidCallback onRecenter;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back / locate controls sit just above the sheet.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MapButton(icon: Icons.arrow_back, onTap: onBack),
              _MapButton(icon: Icons.my_location, onTap: onRecenter),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sizning joylashuvingiz',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                // Picked address card.
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Maxtumquli 11 A',
                              style: TextStyle(
                                fontSize: 16,
                                height: 22 / 16,
                                letterSpacing: -0.18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.navy,
                              ),
                            ),
                            const Text(
                              'Mavjud yetkazib berish',
                              style: TextStyle(
                                fontSize: 14,
                                height: 20 / 14,
                                letterSpacing: -0.16,
                                color: Color(0xFF8D96A4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Optional apartment / entrance / floor field.
                Container(
                  height: 50,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const TextField(
                    style: TextStyle(fontSize: 14, color: AppColors.navy),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Kvartira / podyezd / qavat (ixtiyoriy)',
                      hintStyle: TextStyle(
                        color: Color(0xFF9494A3),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Confirm button — Figma pill: 52px tall, fully rounded.
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: const Text(
                      'Manzilni tasdiqlash',
                      style: TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        letterSpacing: -0.18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
