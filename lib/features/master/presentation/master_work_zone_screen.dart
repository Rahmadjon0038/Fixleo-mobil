import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/location/reverse_geocoder.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_documents_screen.dart';
import 'package:fixleo/features/work_radius/data/work_radius_service.dart';

/// Master onboarding — pick the work zone on a real, movable map. The map
/// slides under a fixed center pin; a translucent circle shows the chosen
/// service radius (3 / 5 / 10 km) around that point.
class MasterWorkZoneScreen extends StatefulWidget {
  const MasterWorkZoneScreen({super.key});

  @override
  State<MasterWorkZoneScreen> createState() => _MasterWorkZoneScreenState();
}

class _MasterWorkZoneScreenState extends State<MasterWorkZoneScreen> {
  /// Tashkent center as a sensible starting point.
  static const _start = LatLng(41.311081, 69.279737);

  /// Used until the backend's allowed radii load (and as offline fallback).
  /// Mirrors the backend seed (see `api/WorkRadius.md`).
  static const _fallbackRadii = [3, 5, 10];

  final _mapController = MapController();
  final _geocoder = ReverseGeocoder();
  final _workRadiusService = WorkRadiusService();
  final _masterService = MasterService();
  bool _saving = false;

  /// Allowed service radii — fetched from `GET /work-radiuses` so the picker
  /// only ever offers values the backend accepts.
  List<int> _radii = _fallbackRadii;

  LatLng _center = _start;
  String? _placeLabel;
  String? _placeSubtitle;
  bool _resolvingPlace = false;
  Timer? _geocodeDebounce;
  int _geocodeToken = 0;
  int _radiusKm = 5;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _loadRadii();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleReverseGeocode(_center, immediate: true);
    });
  }

  /// Pulls the allowed radii from the backend. On any failure we silently keep
  /// the fallback list so onboarding is never blocked by a network hiccup.
  Future<void> _loadRadii() async {
    try {
      final options = await _workRadiusService.getOptions();
      if (!mounted || options.isEmpty) return;
      final kms = options.map((o) => o.km).toList(growable: false);
      setState(() {
        _radii = kms;
        // Keep the current selection if still allowed, otherwise default to
        // the previously-selected 5 km when present, else the first option.
        if (!kms.contains(_radiusKm)) {
          _radiusKm = kms.contains(5) ? 5 : kms.first;
        }
      });
    } on Object {
      // Network / parse error — keep the fallback radii.
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    final moving = event is MapEventMove || event is MapEventFlingAnimation;
    if (moving != _dragging) {
      setState(() => _dragging = moving);
    }
  }

  void _onPositionChanged(MapCamera position, bool hasGesture) {
    setState(() => _center = position.center);
    _scheduleReverseGeocode(position.center);
  }

  void _recenter() {
    setState(() => _center = _start);
    _mapController.move(_start, 12);
    _scheduleReverseGeocode(_start, immediate: true);
  }

  void _scheduleReverseGeocode(LatLng point, {bool immediate = false}) {
    _geocodeDebounce?.cancel();
    if (immediate) {
      _resolvePlace(point);
      return;
    }
    _geocodeDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _resolvePlace(point),
    );
  }

  Future<void> _resolvePlace(LatLng point) async {
    final token = ++_geocodeToken;
    if (mounted) setState(() => _resolvingPlace = true);
    try {
      final result = await _geocoder.resolve(point);
      if (!mounted || token != _geocodeToken) return;
      setState(() {
        _placeLabel = result?.label;
        _placeSubtitle = result?.subtitle;
        _resolvingPlace = false;
      });
    } catch (_) {
      if (!mounted || token != _geocodeToken) return;
      setState(() {
        _placeLabel = null;
        _placeSubtitle = null;
        _resolvingPlace = false;
      });
    }
  }

  /// Saves the base location + radius (`PUT /masters/me/work-zone`) then moves on.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _masterService.setWorkZone(
        latitude: _center.latitude,
        longitude: _center.longitude,
        workRadiusKm: _radiusKm,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MasterDocumentsScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      final lang = LocaleController.language.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(lang, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // The real, movable map fills the whole screen.
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _start,
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 18,
              onMapEvent: _onMapEvent,
              onPositionChanged: _onPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fixleo.app',
              ),
              // Translucent disc showing the selected service radius.
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _center,
                    radius: _radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: AppColors.blue.withValues(alpha: 0.10),
                    borderColor: AppColors.blue,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            ],
          ),

          // Fixed center pin — the map slides beneath it.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -29),
                child: _CenterMarker(lifted: _dragging),
              ),
            ),
          ),

          // Top: brand badge, "Ish hududi" title + back, drag hint.
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                if (shouldShowBrandBar()) const Center(child: BrandBar()),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _TitlePill(
                          tr(lang, 'Ish hududi', 'Рабочая зона', 'Work zone'),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _MapButton(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(
                    lang,
                    'Xaritani siljitish mumkin',
                    'Карту можно двигать',
                    'You can move the map',
                  ),
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

          // Bottom: map controls + work-zone sheet.
          Align(
            alignment: Alignment.bottomCenter,
            child: _WorkZoneSheet(
              lang: lang,
              currentCenter: _center,
              placeLabel: _placeLabel,
              placeSubtitle: _placeSubtitle,
              resolvingPlace: _resolvingPlace,
              radii: _radii,
              selectedRadius: _radiusKm,
              onRadiusChanged: (km) => setState(() => _radiusKm = km),
              onBack: () => Navigator.of(context).maybePop(),
              onRecenter: _recenter,
              onSave: _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small white pill used for the screen title.
class _TitlePill extends StatelessWidget {
  const _TitlePill(this.text);

  final String text;

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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
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

/// Bottom card: floating map controls, picked address, radius selector and
/// the save button.
class _WorkZoneSheet extends StatelessWidget {
  const _WorkZoneSheet({
    required this.lang,
    required this.currentCenter,
    required this.placeLabel,
    required this.placeSubtitle,
    required this.resolvingPlace,
    required this.radii,
    required this.selectedRadius,
    required this.onRadiusChanged,
    required this.onBack,
    required this.onRecenter,
    required this.onSave,
  });

  final AppLanguage lang;
  final LatLng currentCenter;
  final String? placeLabel;
  final String? placeSubtitle;
  final bool resolvingPlace;
  final List<int> radii;
  final int selectedRadius;
  final ValueChanged<int> onRadiusChanged;
  final VoidCallback onBack;
  final VoidCallback onRecenter;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                Text(
                  tr(
                    lang,
                    'Sizning joylashuvingiz',
                    'Ваше местоположение',
                    'Your location',
                  ),
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
                            Text(
                              placeLabel ??
                                  tr(
                                    lang,
                                    'Tanlangan joy',
                                    'Выбранное место',
                                    'Selected place',
                                  ),
                              style: TextStyle(
                                fontSize: 16,
                                height: 22 / 16,
                                letterSpacing: -0.18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              resolvingPlace
                                  ? tr(
                                      lang,
                                      'Aniqlanmoqda...',
                                      'Определяем...',
                                      'Resolving...',
                                    )
                                  : placeSubtitle ??
                                        tr(
                                          lang,
                                          'Koordinata bo‘yicha tanlandi',
                                          'Выбрано по координатам',
                                          'Selected by coordinates',
                                        ),
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
                const SizedBox(height: 8),
                Text(
                  '${currentCenter.latitude.toStringAsFixed(6)}, ${currentCenter.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    letterSpacing: -0.08,
                    color: Color(0xFF8D96A4),
                  ),
                ),
                const SizedBox(height: 10),
                // Radius selector — 3 / 5 / 10 km.
                Row(
                  children: [
                    for (var i = 0; i < radii.length; i++) ...[
                      if (i != 0) const SizedBox(width: 8),
                      Expanded(
                        child: _RadiusPill(
                          km: radii[i],
                          selected: radii[i] == selectedRadius,
                          onTap: () => onRadiusChanged(radii[i]),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: Text(
                      tr(
                        lang,
                        'Hududni saqlash',
                        'Сохранить зону',
                        'Save zone',
                      ),
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

/// One radius option ("5 km") — filled blue when selected, outlined gray
/// otherwise.
class _RadiusPill extends StatelessWidget {
  const _RadiusPill({
    required this.km,
    required this.selected,
    required this.onTap,
  });

  final int km;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.blue : const Color(0xFFF1F5F9),
          ),
        ),
        child: Text(
          '$km km',
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF8D96A4),
          ),
        ),
      ),
    );
  }
}
