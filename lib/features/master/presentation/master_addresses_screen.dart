import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_work_zone_screen.dart';

/// Master's saved work address.
///
/// A master currently has one canonical base address because the marketplace
/// radius and nearby-order feed are both calculated from that same point.
/// Keeping it in a dedicated "My addresses" screen makes the location easy to
/// find and edit without creating a second, conflicting source of truth.
class MasterAddressesScreen extends StatefulWidget {
  const MasterAddressesScreen({super.key, this.service, this.initialMaster});

  final MasterService? service;
  final Master? initialMaster;

  @override
  State<MasterAddressesScreen> createState() => _MasterAddressesScreenState();
}

class _MasterAddressesScreenState extends State<MasterAddressesScreen> {
  late final MasterService _service = widget.service ?? MasterService();
  Master? _master;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _master = widget.initialMaster;
    _load(showLoading: _master == null);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final master = await _service.me();
      if (!mounted) return;
      setState(() {
        _master = master;
        _loading = false;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr(
          LocaleController.language.value,
          'Manzilni yuklab bo‘lmadi',
          'Не удалось загрузить адрес',
          'Could not load the address',
        );
      });
    }
  }

  Future<void> _openEditor() async {
    final master = _master;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MasterWorkZoneScreen(
          isEditing: true,
          initialLatitude: master?.latitude,
          initialLongitude: master?.longitude,
          initialRadiusKm: master?.workRadiusKm,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Mening manzillarim', 'Мои адреса', 'My addresses'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(child: _content(lang)),
            const SizedBox(height: 12),
            GlassButton(
              label: _hasAddress
                  ? tr(
                      lang,
                      'Manzilni o‘zgartirish',
                      'Изменить адрес',
                      'Change address',
                    )
                  : tr(lang, 'Yangi manzil', 'Новый адрес', 'New address'),
              icon: _hasAddress
                  ? Icons.edit_location_alt_outlined
                  : Icons.add_location_alt_outlined,
              onPressed: _loading ? null : _openEditor,
              height: 52,
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasAddress =>
      _master?.latitude != null && _master?.longitude != null;

  Widget _content(AppLanguage lang) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _master == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            LiquidActionButton.text(
              onPressed: _load,
              child: Text(tr(lang, 'Qayta urinish', 'Повторить', 'Retry')),
            ),
          ],
        ),
      );
    }
    if (!_hasAddress) {
      return Center(
        child: Text(
          tr(
            lang,
            'Saqlangan manzil yo‘q',
            'Нет сохранённого адреса',
            'No saved address',
          ),
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }

    final master = _master!;
    final coordinate =
        '${master.latitude!.toStringAsFixed(5)}, ${master.longitude!.toStringAsFixed(5)}';
    final label = master.baseLabel?.trim();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          GestureDetector(
            onTap: _openEditor,
            child: GlassContainer.lite(
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  LiquidSurface(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEAF4FE),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label?.isNotEmpty == true
                              ? label!
                              : tr(
                                  lang,
                                  'Ish manzili',
                                  'Рабочий адрес',
                                  'Work address',
                                ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          coordinate,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          tr(
                            lang,
                            'Asosiy · ${master.workRadiusKm ?? 0} km ish radiusi',
                            'Основной · радиус работы ${master.workRadiusKm ?? 0} км',
                            'Default · ${master.workRadiusKm ?? 0} km work radius',
                          ),
                          style: const TextStyle(
                            color: AppColors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
