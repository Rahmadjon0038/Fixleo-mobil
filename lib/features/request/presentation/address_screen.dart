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
import 'package:fixleo/core/location/reverse_geocoder.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';
import 'package:fixleo/features/request/data/new_order_draft.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/time_urgency_screen.dart';

/// A real, draggable map where the user pins a location. The map moves under
/// a fixed center marker, so wherever the map is dropped is the chosen spot.
///
/// Used in two places:
/// - the "new request" flow (default): confirm → time/urgency step;
/// - client onboarding ([isOnboarding]): "Saqlash" → main screen.
class AddressScreen extends StatefulWidget {
  const AddressScreen({
    super.key,
    this.isOnboarding = false,
    this.isEditingHome = false,
    this.initialAddress,
    this.draft,
    this.locationService,
    this.geocoder,
    this.orderService,
    this.loadMapTiles = true,
  });

  /// True right after registration — the button says "Saqlash" and leads to
  /// the home screen instead of continuing the request flow.
  final bool isOnboarding;

  /// Opens from the client home header and saves the selected default address.
  final bool isEditingHome;

  final ClientAddress? initialAddress;

  /// The in-progress order (null during onboarding).
  final NewOrderDraft? draft;

  final DeviceLocationService? locationService;
  final ReverseGeocoder? geocoder;
  final OrderService? orderService;
  final bool loadMapTiles;

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  /// Neutral world view shown only until device GPS resolves.
  static const _worldCenter = ll.LatLng(20, 0);

  gmap.GoogleMapController? _mapController;
  late final OrderService _orders;
  final _detailsController = TextEditingController();
  late final DeviceLocationService _locationService;
  late final ReverseGeocoder _geocoder;

  /// Current selected map center.
  late final ll.LatLng _initialCenter;
  late final double _initialZoom;
  late ll.LatLng _center;
  String? _placeLabel;
  String? _placeSubtitle;
  bool _resolvingPlace = false;
  Timer? _geocodeDebounce;
  int _geocodeToken = 0;
  bool _savingHome = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? DeviceLocationService();
    _geocoder = widget.geocoder ?? ReverseGeocoder();
    _orders = widget.orderService ?? OrderService();
    final initial = widget.initialAddress;
    _initialCenter = initial == null
        ? _worldCenter
        : ll.LatLng(initial.latitude, initial.longitude);
    _initialZoom = initial == null ? 2 : 16;
    _center = _initialCenter;
    _detailsController.text = initial?.details ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (initial == null) {
        unawaited(_locateCurrent(showErrors: true));
      } else {
        _scheduleReverseGeocode(_center, immediate: true);
      }
    });
  }

  /// Whether the map is mid-drag (used to lift the pin a touch for feedback).
  bool _dragging = false;

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _detailsController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(gmap.GoogleMapController controller) {
    _mapController = controller;
    if (_center != _initialCenter) {
      unawaited(
        controller.animateCamera(
          gmap.CameraUpdate.newLatLngZoom(_toGoogle(_center), 16),
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

  Future<void> _locateCurrent({required bool showErrors}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final point = await _locationService.currentLocation();
      if (!mounted) return;
      setState(() => _center = point);
      await _mapController?.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(_toGoogle(point), 16),
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

  String _addressText() {
    final value = [?_placeLabel, ?_placeSubtitle].join(', ').trim();
    return value.isNotEmpty
        ? value
        : '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';
  }

  Future<void> _saveHomeAddress() async {
    if (_savingHome) return;
    setState(() => _savingHome = true);
    try {
      final saved = await _orders.saveAddress(
        id: widget.initialAddress?.id,
        addressText: _addressText(),
        latitude: _center.latitude,
        longitude: _center.longitude,
        details: _detailsController.text.trim(),
      );
      if (!mounted) return;
      if (widget.isEditingHome) {
        Navigator.of(context).pop(saved);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _savingHome = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GlassBackground(
        baseColor: AppColors.background,
        child: Stack(
          children: [
            // The real, movable map fills the whole screen.
            if (widget.loadMapTiles)
              gmap.GoogleMap(
                initialCameraPosition: gmap.CameraPosition(
                  target: _toGoogle(_initialCenter),
                  zoom: _initialZoom,
                ),
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
                  if (shouldShowBrandBar()) const Center(child: BrandBar()),
                  const SizedBox(height: 18),
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

            // Bottom sheet with the picked address and confirm button.
            Align(
              alignment: Alignment.bottomCenter,
              child: _AddressSheet(
                currentCenter: _center,
                placeLabel: _placeLabel,
                placeSubtitle: _placeSubtitle,
                resolvingPlace: _resolvingPlace,
                onBack: () => Navigator.of(context).maybePop(),
                onRecenter: () => _locateCurrent(showErrors: true),
                locating: _locating,
                confirmLabel: widget.isOnboarding || widget.isEditingHome
                    ? tr(lang, 'Saqlash', 'Сохранить', 'Save')
                    : tr(
                        lang,
                        'Manzilni tasdiqlash',
                        'Подтвердить адрес',
                        'Confirm address',
                      ),
                showDetailsField: !widget.isOnboarding,
                detailsController: _detailsController,
                isSaving: _savingHome,
                onConfirm: () {
                  if (widget.isOnboarding || widget.isEditingHome) {
                    _saveHomeAddress();
                  } else {
                    final draft = widget.draft ?? NewOrderDraft();
                    draft
                      ..latitude = _center.latitude
                      ..longitude = _center.longitude
                      ..addressText = _addressText()
                      ..addressDetails = _detailsController.text.trim();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TimeUrgencyScreen(draft: draft),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
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
      onTap: isLoading ? null : onTap,
      size: 44,
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

/// Bottom card: floating map controls + the picked-address sheet.
class _AddressSheet extends StatelessWidget {
  const _AddressSheet({
    required this.currentCenter,
    required this.placeLabel,
    required this.placeSubtitle,
    required this.resolvingPlace,
    required this.onBack,
    required this.onRecenter,
    required this.locating,
    required this.onConfirm,
    required this.confirmLabel,
    required this.detailsController,
    required this.isSaving,
    this.showDetailsField = true,
  });

  final ll.LatLng currentCenter;
  final String? placeLabel;
  final String? placeSubtitle;
  final bool resolvingPlace;
  final VoidCallback onBack;
  final VoidCallback onRecenter;
  final bool locating;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final TextEditingController detailsController;
  final bool isSaving;

  /// Whether to show the optional apartment/entrance/floor field (hidden
  /// during onboarding, matching the design).
  final bool showDetailsField;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
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
              _MapButton(
                icon: Icons.my_location,
                onTap: onRecenter,
                isLoading: locating,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 30,
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
                  height: 50,
                  borderRadius: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  tint: AppColors.background,
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
                if (showDetailsField) ...[
                  const SizedBox(height: 10),
                  // Optional apartment / entrance / floor field.
                  GlassTextField(
                    controller: detailsController,
                    height: 50,
                    textStyle: TextStyle(fontSize: 14, color: AppColors.navy),
                    hintText: tr(
                      lang,
                      'Kvartira / podyezd / qavat (ixtiyoriy)',
                      'Квартира / подъезд / этаж (необязательно)',
                      'Apartment / entrance / floor (optional)',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Confirm button — Figma pill: 52px tall, fully rounded.
                GlassButton(
                  label: confirmLabel,
                  onPressed: isSaving ? null : onConfirm,
                  height: 52,
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
