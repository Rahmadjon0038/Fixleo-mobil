import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/address_screen.dart';

/// Client address book backed by `GET /clients/me/addresses`.
///
/// Every row opens the existing real Google Maps editor. The bottom action
/// creates a new address and makes it the client's default location.
class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key, this.orderService});

  final OrderService? orderService;

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  late final OrderService _orders = widget.orderService ?? OrderService();
  List<ClientAddress> _addresses = const [];
  bool _loading = true;
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
        builder: (_) =>
            AddressScreen(isEditingHome: true, initialAddress: address),
      ),
    );
    if (saved != null && mounted) await _load();
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
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(
                  tr(lang, 'Yangi manzil', 'Новый адрес', 'New address'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
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
          return Semantics(
            button: true,
            label: address.addressText,
            child: InkWell(
              onTap: () => _openEditor(address),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
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
                    const Icon(Icons.chevron_right, color: AppColors.muted),
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
