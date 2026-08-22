import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/address_screen.dart';

/// Client address book backed by `GET /clients/me/addresses`.
///
/// In profile mode every row opens the Google Maps editor. In selection mode
/// a row becomes the client's default location and is returned to the caller.
/// The bottom action creates a new address in both modes.
class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({
    super.key,
    this.orderService,
    this.selectionMode = false,
    this.selectedAddressId,
  });

  final OrderService? orderService;
  final bool selectionMode;
  final int? selectedAddressId;

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  late final OrderService _orders = widget.orderService ?? OrderService();
  List<ClientAddress> _addresses = const [];
  bool _loading = true;
  int? _selectingAddressId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await _orders.addresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([ClientAddress? address]) async {
    final saved = await Navigator.of(context).push<ClientAddress>(
      MaterialPageRoute(
        builder: (_) => AddressScreen(
          isEditingHome: true,
          initialAddress: address,
          orderService: _orders,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    if (widget.selectionMode) {
      Navigator.of(context).pop(saved);
      return;
    }
    await _load();
  }

  Future<void> _selectAddress(ClientAddress address) async {
    if (_selectingAddressId != null) return;
    setState(() => _selectingAddressId = address.id);
    try {
      final saved = await _orders.saveAddress(
        id: address.id,
        label: address.label,
        addressText: address.addressText,
        district: address.district,
        latitude: address.latitude,
        longitude: address.longitude,
        details: address.details,
        isDefault: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _selectingAddressId = null);
    } on Object {
      if (!mounted) return;
      final lang = LocaleController.language.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Manzilni tanlab bo‘lmadi',
              'Не удалось выбрать адрес',
              'Could not select the address',
            ),
          ),
        ),
      );
      setState(() => _selectingAddressId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: widget.selectionMode
          ? tr(lang, 'Manzilni tanlang', 'Выберите адрес', 'Choose an address')
          : tr(lang, 'Mening manzillarim', 'Мои адреса', 'My addresses'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(child: _content(lang)),
            const SizedBox(height: 12),
            GlassButton(
              label: tr(lang, 'Yangi manzil', 'Новый адрес', 'New address'),
              icon: Icons.add_location_alt_outlined,
              onPressed: () => _openEditor(),
              height: 52,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppLanguage lang) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(
              onPressed: _load,
              child: Text(tr(lang, 'Qayta urinish', 'Повторить', 'Retry')),
            ),
          ],
        ),
      );
    }
    if (_addresses.isEmpty) {
      return Center(
        child: Text(
          tr(
            lang,
            'Saqlangan manzillar yoʻq',
            'Нет сохранённых адресов',
            'No saved addresses',
          ),
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _addresses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final address = _addresses[index];
          final isSelected =
              address.id == widget.selectedAddressId ||
              (widget.selectedAddressId == null && address.isDefault);
          final isSelecting = _selectingAddressId == address.id;
          return Semantics(
            button: true,
            selected: widget.selectionMode && isSelected,
            label: address.addressText,
            child: GestureDetector(
              onTap: _selectingAddressId != null
                  ? null
                  : widget.selectionMode
                  ? () => _selectAddress(address)
                  : () => _openEditor(address),
              child: GlassContainer.lite(
                borderRadius: 24,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
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
                            address.label?.trim().isNotEmpty == true
                                ? address.label!
                                : address.addressText,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (address.label?.trim().isNotEmpty == true)
                            Text(
                              address.addressText,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          if (address.isDefault)
                            Text(
                              tr(lang, 'Asosiy', 'Основной', 'Default'),
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSelecting)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      Icon(
                        widget.selectionMode
                            ? isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded
                            : Icons.chevron_right,
                        color: widget.selectionMode && isSelected
                            ? AppColors.blue
                            : AppColors.muted,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
