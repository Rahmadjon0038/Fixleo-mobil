import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as ll;

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/location/device_location_feedback.dart';
import 'package:fixleo/core/location/device_location_service.dart';
import 'package:fixleo/core/location/place_search_field.dart';
import 'package:fixleo/core/location/place_search_service.dart';
import 'package:fixleo/core/location/reverse_geocoder.dart';
import 'package:fixleo/core/permissions/permission_prompt.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_documents_screen.dart';
import 'package:fixleo/features/work_radius/data/work_radius_service.dart';

/// Master onboarding — pick the work zone on a real, movable map. The map
/// slides under a fixed center pin; a translucent circle shows the chosen
/// service radius (3 / 5 / 10 km) around that point.
class MasterWorkZoneScreen extends StatefulWidget {
  const MasterWorkZoneScreen({
    super.key,
    this.isEditing = false,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadiusKm,
    this.locationService,
    this.geocoder,
    this.placeSearchService,
    this.workRadiusService,
    this.masterService,
    this.loadMapTiles = true,
  });

  final bool isEditing;
  final double? initialLatitude;
  final double? initialLongitude;
  final int? initialRadiusKm;
  final DeviceLocationService? locationService;
  final ReverseGeocoder? geocoder;
  final PlaceSearchService? placeSearchService;
  final WorkRadiusService? workRadiusService;
  final MasterService? masterService;
  final bool loadMapTiles;

  @override
  State<MasterWorkZoneScreen> createState() => _MasterWorkZoneScreenState();
}

class _MasterWorkZoneScreenState extends State<MasterWorkZoneScreen> {
  /// Neutral world view shown only until device GPS resolves.
  static const _worldCenter = ll.LatLng(20, 0);

  /// Used until the backend's allowed radii load (and as offline fallback).
  /// Mirrors the backend seed (see `api/WorkRadius.md`).
  static const _fallbackRadii = [3, 5, 10];

  gmap.GoogleMapController? _mapController;
  late final DeviceLocationService _locationService;
  late final ReverseGeocoder _geocoder;
  late final PlaceSearchService _placeSearchService;
  late final WorkRadiusService _workRadiusService;
  late final MasterService _masterService;
  bool _saving = false;

  /// Allowed service radii — fetched from `GET /work-radiuses` so the picker
  /// only ever offers values the backend accepts.
  List<int> _radii = _fallbackRadii;

  late final ll.LatLng _initialCenter;
  late final double _initialZoom;
  late ll.LatLng _center;
  String? _placeLabel;
  String? _placeSubtitle;
  bool _resolvingPlace = false;
  Timer? _geocodeDebounce;
  int _geocodeToken = 0;
  late int _radiusKm;
  bool _dragging = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? DeviceLocationService();
    _geocoder = widget.geocoder ?? ReverseGeocoder();
    _placeSearchService = widget.placeSearchService ?? PlaceSearchService();
    _workRadiusService = widget.workRadiusService ?? WorkRadiusService();
    _masterService = widget.masterService ?? MasterService();
    final hasInitial =
        widget.initialLatitude != null && widget.initialLongitude != null;
    _initialCenter = !hasInitial
        ? _worldCenter
        : ll.LatLng(widget.initialLatitude!, widget.initialLongitude!);
    _initialZoom = hasInitial ? 12 : 2;
    _center = _initialCenter;
    _radiusKm = widget.initialRadiusKm ?? 5;
    _loadRadii();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasInitial) {
        unawaited(_locateCurrent(showErrors: true, explainPermission: true));
      } else {
        _scheduleReverseGeocode(_center, immediate: true);
      }
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
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(gmap.GoogleMapController controller) {
    _mapController = controller;
    if (_center != _initialCenter) {
      unawaited(
        controller.animateCamera(
          gmap.CameraUpdate.newLatLngZoom(_toGoogle(_center), 14),
        ),
      );
    }
  }

  void _onCameraMoveStarted() {
    if (!_dragging && mounted) {
      setState(() => _dragging = true);
    }
  }

  void _onCameraMove(gmap.CameraPosition position) {
    _center = ll.LatLng(position.target.latitude, position.target.longitude);
  }

  void _onCameraIdle() {
    if (!mounted) return;
    setState(() => _dragging = false);
    _scheduleReverseGeocode(_center);
  }

  Future<void> _locateCurrent({
    required bool showErrors,
    bool explainPermission = false,
  }) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final permission = await _locationService.permissionState();
      if (!mounted) return;
      if (explainPermission &&
          permission == DeviceLocationPermissionState.denied) {
        final shouldContinue = await showPermissionRationale(
          context,
          icon: Icons.my_location_rounded,
          titleUz: 'Joylashuvga ruxsat',
          titleRu: 'Доступ к геолокации',
          titleEn: 'Location permission',
          messageUz:
              'Fixleo ish hududingizni hozirgi joyingizdan boshlash va yaqin buyurtmalarni topish uchun joylashuvga ruxsat so‘raydi.',
          messageRu:
              'Fixleo запрашивает геолокацию, чтобы задать рабочую зону от вашего текущего места и находить ближайшие заказы.',
          messageEn:
              'Fixleo uses location to set your work zone from your current position and find nearby orders.',
        );
        if (!shouldContinue || !mounted) return;
      }
      final point = await _locationService.currentLocation();
      if (!mounted) return;
      setState(() => _center = point);
      await _mapController?.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(_toGoogle(point), 14),
      );
      _scheduleReverseGeocode(point, immediate: true);
    } on DeviceLocationException catch (error) {
      if (showErrors && mounted) {
        showDeviceLocationFailure(context, error, _locationService);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  gmap.LatLng _toGoogle(ll.LatLng point) =>
      gmap.LatLng(point.latitude, point.longitude);

  void _scheduleReverseGeocode(ll.LatLng point, {bool immediate = false}) {
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

  Future<void> _resolvePlace(ll.LatLng point) async {
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

  Future<void> _selectSearchResult(PlaceSearchResult result) async {
    _geocodeDebounce?.cancel();
    final point = result.point;
    setState(() {
      _center = point;
      _placeLabel = result.label;
      _placeSubtitle = result.subtitle;
      _resolvingPlace = false;
      _dragging = false;
    });
    await _mapController?.animateCamera(
      gmap.CameraUpdate.newLatLngZoom(_toGoogle(point), 14),
    );
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
        baseLabel: [?_placeLabel, ?_placeSubtitle].join(', '),
      );
      if (!mounted) return;
      if (widget.isEditing) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MasterDocumentsScreen()),
        );
      }
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
      body: GlassBackground(
        child: Stack(
          children: [
            // The real, movable map fills the whole screen.
            if (widget.loadMapTiles)
              gmap.GoogleMap(
                initialCameraPosition: gmap.CameraPosition(
                  target: _toGoogle(_initialCenter),
                  zoom: _initialZoom,
                ),
                circles: {
                  gmap.Circle(
                    circleId: const gmap.CircleId('work-zone'),
                    center: _toGoogle(_center),
                    radius: _radiusKm * 1000,
                    fillColor: AppColors.blue.withValues(alpha: 0.10),
                    strokeColor: AppColors.blue,
                    strokeWidth: 2,
                  ),
                },
                minMaxZoomPreference: const gmap.MinMaxZoomPreference(2, 20),
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: _onMapCreated,
                onCameraMoveStarted: _onCameraMoveStarted,
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
              )
            else
              const ColoredBox(color: Color(0xFFE8EFF6)),

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
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PlaceSearchField(
                      language: lang,
                      service: _placeSearchService,
                      bias: _center,
                      onSelected: _selectSearchResult,
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
                onRecenter: () =>
                    _locateCurrent(showErrors: true, explainPermission: true),
                locating: _locating,
                onSave: _save,
                isSaving: _saving,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small frosted-glass pill used for the screen title.
class _TitlePill extends StatelessWidget {
  const _TitlePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.center,
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
  const _MapButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      size: 44,
      onTap: isLoading ? null : onTap,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.blue,
              ),
            )
          : Icon(icon, size: 22, color: AppColors.navy),
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
    required this.locating,
    required this.onSave,
    required this.isSaving,
  });

  final AppLanguage lang;
  final ll.LatLng currentCenter;
  final String? placeLabel;
  final String? placeSubtitle;
  final bool resolvingPlace;
  final List<int> radii;
  final int selectedRadius;
  final ValueChanged<int> onRadiusChanged;
  final VoidCallback onBack;
  final VoidCallback onRecenter;
  final bool locating;
  final VoidCallback onSave;
  final bool isSaving;

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
              _MapButton(
                icon: Icons.my_location,
                onTap: onRecenter,
                isLoading: locating,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Outer ClipRRect gives the glass panel its top-only rounding (a
        // GlassContainer alone only supports uniform corner radii) while the
        // frosted blur/tint/border still comes entirely from GlassContainer.
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: GlassContainer(
            borderRadius: 0,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                  GlassContainer.lite(
                    tint: AppColors.background,
                    height: 50,
                    borderRadius: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  // Admins may add more radius options than fit on one row.
                  // Keep the common 3-option layout evenly distributed, and
                  // make longer dynamic lists horizontally scrollable.
                  if (radii.length <= 3)
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
                    )
                  else
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: radii.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => SizedBox(
                          width: 68,
                          child: _RadiusPill(
                            km: radii[i],
                            selected: radii[i] == selectedRadius,
                            onTap: () => onRadiusChanged(radii[i]),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  GlassButton(
                    label: isSaving
                        ? tr(
                            lang,
                            'Saqlanmoqda...',
                            'Сохранение...',
                            'Saving...',
                          )
                        : tr(
                            lang,
                            'Hududni saqlash',
                            'Сохранить зону',
                            'Save zone',
                          ),
                    onPressed: isSaving ? null : onSave,
                    height: 52,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
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
    final text = Text(
      '$km km',
      maxLines: 1,
      style: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? Colors.white : const Color(0xFF8D96A4),
      ),
    );
    // .lite (no BackdropFilter) since this pill is reused inside a
    // horizontally scrolling ListView when there are more than 3 radii.
    return GestureDetector(
      onTap: onTap,
      child: selected
          ? GlassContainer.lite(
              tint: AppColors.blue,
              tintOpacityTop: 0.9,
              tintOpacityBottom: 0.74,
              borderOpacity: 0.5,
              height: 36,
              borderRadius: 999,
              alignment: Alignment.center,
              child: text,
            )
          : GlassContainer.lite(
              height: 36,
              borderRadius: 999,
              alignment: Alignment.center,
              child: text,
            ),
    );
  }
}
