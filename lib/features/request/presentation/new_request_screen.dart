import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/request/data/new_order_draft.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/address_screen.dart';

/// Step 1 of the "new request" flow — the category, task description and up to
/// 6 problem photos. "Next" uploads the photos and carries a [NewOrderDraft]
/// on to the location-picking map.
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key, this.categoryId, this.categoryName});

  final int? categoryId;
  final String? categoryName;

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  static const _maxPhotos = 6;

  final _description = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile?> _photos = List.filled(_maxPhotos, null);
  final OrderService _orders = OrderService();

  int? _categoryId;
  String? _categoryName;
  List<Category> _categories = const [];
  bool _submitting = false;

  int get _firstEmpty => _photos.indexWhere((p) => p == null);

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
    _categoryName = widget.categoryName;
    if (_categoryId == null) _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await CategoryService().getAll();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        if (_categoryId == null && cats.isNotEmpty) {
          _categoryId = cats.first.id;
          _categoryName = cats.first.name;
        }
      });
    } on ApiException {
      // keep the placeholder pill; create will surface a clear error
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _photos[index] = file);
  }

  void _remove(int index) => setState(() => _photos[index] = null);

  Future<void> _pickCategory() async {
    if (_categories.isEmpty) return;
    final lang = LocaleController.language.value;
    final chosen = await showModalBottomSheet<Category>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(lang, 'Kategoriya', 'Категория', 'Category'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final c in _categories)
              ListTile(title: Text(c.name), onTap: () => Navigator.of(ctx).pop(c)),
          ],
        ),
      ),
    );
    if (chosen != null) {
      setState(() {
        _categoryId = chosen.id;
        _categoryName = chosen.name;
      });
    }
  }

  Future<void> _next() async {
    final lang = LocaleController.language.value;
    final desc = _description.text.trim();
    if (_categoryId == null) {
      _snack(tr(lang, 'Kategoriyani tanlang', 'Выберите категорию', 'Pick a category'));
      return;
    }
    if (desc.length < 10) {
      _snack(tr(lang, 'Vazifani batafsilroq yozing (min 10 belgi)',
          'Опишите задачу подробнее (мин. 10 символов)', 'Describe the task (min 10 chars)'));
      return;
    }
    setState(() => _submitting = true);
    final draft = NewOrderDraft(categoryId: _categoryId, categoryName: _categoryName)
      ..description = desc;
    try {
      for (final p in _photos) {
        if (p != null) {
          final uploaded = await _orders.uploadPhoto(p.path);
          draft.photoKeys.add(uploaded.fileKey);
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddressScreen(draft: draft)),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Yangi buyurtma', 'Новый заказ', 'New request'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.categoryId == null ? _pickCategory : null,
                      child: _CategoryPill(
                        label: _categoryName ??
                            tr(lang, 'Kategoriya tanlang', 'Выберите категорию', 'Pick a category'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DescribeCard(controller: _description, lang: lang),
                    const SizedBox(height: 12),
                    _photosCard(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            PrimaryButton(
              label: _submitting
                  ? tr(lang, 'Yuklanmoqda…', 'Загрузка…', 'Uploading…')
                  : tr(lang, 'Keyingi', 'Далее', 'Next'),
              onPressed: _submitting ? null : _next,
            ),
          ],
        ),
      ),
    );
  }

  /// White card with the "add up to 6 photos" hint and the 2×3 photo grid.
  Widget _photosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              LocaleController.language.value,
              '6 tagacha rasm qoʻshing — ustaga vazifani baholash osonroq boʻladi',
              'Добавьте до 6 фото — мастеру будет проще оценить задачу',
              'Add up to 6 photos so the master can estimate the job more easily',
            ),
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: AppColors.navy.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          for (var r = 0; r < 2; r++) ...[
            if (r != 0) const SizedBox(height: 12),
            Row(
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c != 0) const SizedBox(width: 12),
                  Expanded(
                    child: _PhotoSlot(
                      file: _photos[r * 3 + c],
                      active: r * 3 + c == _firstEmpty,
                      onTap: () => _pick(r * 3 + c),
                      onRemove: () => _remove(r * 3 + c),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icon/Waterdrop.svg', width: 18, height: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescribeCard extends StatelessWidget {
  const _DescribeCard({required this.controller, required this.lang});

  final TextEditingController controller;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(lang, 'Vazifani tasvirlang', 'Опишите задачу', 'Describe the task'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: tr(
                  lang,
                  'Masalan: oshxonadagi smesitel oqyapti, kartrijni almashtirish kerak...',
                  'Например: на кухне течёт смеситель, нужно заменить картридж...',
                  'For example: the kitchen faucet is leaking; the cartridge needs to be replaced...',
                ),
                hintStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Address preview card — a static mini-map with a pin and a
/// "Manzilni tasdiqlash" row; tapping it opens the map picker.
class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.onTap, required this.lang});

  final VoidCallback onTap;
  final AppLanguage lang;

  /// Tashkent center, same starting point as the picker map.
  static const _center = LatLng(41.311081, 69.279737);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 140,
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: const MapOptions(
                          initialCenter: _center,
                          initialZoom: 13,
                          interactionOptions: InteractionOptions(
                            flags: InteractiveFlag.none,
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
                      const Center(
                        child: Icon(
                          Icons.location_on,
                          size: 36,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(lang, 'Manzilni tasdiqlash', 'Подтвердить адрес', 'Confirm address'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.file,
    required this.active,
    required this.onTap,
    required this.onRemove,
  });

  final XFile? file;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: file != null ? _filled(context) : _empty(),
    );
  }

  Widget _filled(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(File(file!.path), fit: BoxFit.cover),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    final borderColor = active
        ? AppColors.blue
        : AppColors.navy.withValues(alpha: 0.20);
    final iconColor = active
        ? AppColors.blue
        : AppColors.navy.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: borderColor, radius: 16),
        child: Container(
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEAF4FE) : const Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.photo_camera_outlined, color: iconColor, size: 26),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border around the child.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, this.radius = 16});

  final Color color;
  final double radius;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
