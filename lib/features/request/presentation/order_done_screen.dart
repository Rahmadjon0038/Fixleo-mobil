import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';
import 'package:fixleo/features/request/presentation/order_complaint_screen.dart';
import 'package:fixleo/features/wallet/presentation/payment_screen.dart';

/// "Buyurtma bajarildimi?" — the master marked the work done; the user confirms
/// completion or reports a problem, using the real order details.
class OrderDoneScreen extends StatefulWidget {
  const OrderDoneScreen({super.key, required this.orderId, this.orderService});

  final int orderId;
  final OrderService? orderService;

  static const _slate100 = Color(0xFFF1F5F9);
  static const _gray = Color(0xFF8D96A4);

  @override
  State<OrderDoneScreen> createState() => _OrderDoneScreenState();
}

class _OrderDoneScreenState extends State<OrderDoneScreen> {
  late final OrderService _service = widget.orderService ?? OrderService();
  OrderDetail? _order;
  bool _loading = true;
  bool _busy = false;
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
      final order = await _service.detail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  static String _money(int? value) {
    if (value == null) return '—';
    final raw = value.toString();
    final formatted = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) formatted.write(' ');
      formatted.write(raw[i]);
    }
    return formatted.toString();
  }

  String _serviceTitle(OrderDetail order) => order.title.trim().isNotEmpty
      ? order.title.trim()
      : order.description.trim();

  Future<void> _confirm() async {
    final order = _order;
    if (order == null || _busy) return;
    final lang = LocaleController.language.value;
    setState(() => _busy = true);
    try {
      await _service.confirmCompletion(widget.orderId);
      if (!mounted) return;
      final amount = order.finalAmount ?? order.agreedPrice;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            orderId: widget.orderId,
            amount: '${_money(amount)} ${tr(lang, 'soʻm', 'сум', 'sum')}',
            subtitle: '${_serviceTitle(order)} · #${widget.orderId}',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Buyurtma bajarildimi?',
        'Заказ выполнен?',
        'Was the job completed?',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || _order == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ??
                          tr(
                            lang,
                            'Buyurtmani yuklab boʻlmadi',
                            'Не удалось загрузить заказ',
                            'Could not load the order',
                          ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: OrderDoneScreen._gray),
                    ),
                    LiquidActionButton.text(
                      onPressed: _load,
                      child: Text(
                        tr(lang, 'Qayta urinish', 'Повторить', 'Retry'),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _statusCard(),
                          const SizedBox(height: 10),
                          _detailsCard(_order!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _actions(context),
                ],
              ),
      ),
    );
  }

  /// Centered badge + headline confirming the master's report.
  Widget _statusCard() {
    final lang = LocaleController.language.value;
    return GlassCard(
      radius: 30,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          LiquidSurface(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: OrderDoneScreen._slate100,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.verified, size: 42, color: AppColors.blue),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 196,
            child: Text(
              tr(
                lang,
                'Usta ishni bajarilgan deb belgiladi',
                'Мастер отметил работу как выполненную',
                'The master marked the job as completed',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 22 / 16,
                letterSpacing: -0.18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Order summary rows.
  Widget _detailsCard(OrderDetail order) {
    final lang = LocaleController.language.value;
    final price = order.finalAmount ?? order.agreedPrice;
    final afterPhotos = order.photos
        .where((photo) => photo.kind == 'after' && photo.url.isNotEmpty)
        .toList(growable: false);
    return GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _DetailRow(
            label: tr(lang, 'Xizmat', 'Услуга', 'Service'),
            value: _serviceTitle(order),
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: tr(lang, 'Vaqt', 'Время', 'Time'),
            value: orderTimingLabel(
              lang,
              timing: order.timing,
              scheduledDate: order.scheduledDate,
              slotLabel: order.slotLabel,
            ),
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: tr(
              lang,
              'Usta taklifi',
              'Предложение мастера',
              'Master offer',
            ),
            value: '${_money(price)} ${tr(lang, 'soʻm', 'сум', 'sum')}',
          ),
          if (afterPhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(lang, 'Ish natijasi', 'Результат работы', 'Work result'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: afterPhotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    afterPhotos[index].url,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => LiquidSurface(
                      width: 72,
                      height: 72,
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: OrderDoneScreen._gray,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Primary confirm button + a muted "report a problem" link.
  Widget _actions(BuildContext context) {
    final lang = LocaleController.language.value;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          // Custom GlassContainer button (mirrors GlassButton's primary
          // variant) instead of GlassButton itself, since this action needs
          // a busy-spinner swap that GlassButton's fixed label slot doesn't
          // support.
          child: Semantics(
            button: true,
            enabled: !_busy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _confirm,
              child: ExcludeSemantics(
                child: GlassContainer(
                  tint: _busy
                      ? AppColors.blue.withValues(alpha: 0.5)
                      : AppColors.blue,
                  tintOpacityTop: 0.90,
                  tintOpacityBottom: 0.74,
                  borderOpacity: 0.5,
                  borderRadius: 26,
                  height: 52,
                  shadow: !_busy,
                  shadowColor: AppColors.blue,
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          tr(
                            lang,
                            'Bajarilganini tasdiqlash',
                            'Подтвердить выполнение',
                            'Confirm completion',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 22 / 16,
                            letterSpacing: -0.18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderComplaintScreen(orderId: widget.orderId),
              ),
            );
          },
          child: Text(
            tr(
              lang,
              'Buyurtmada muammo bor',
              'Есть проблема с заказом',
              'There is a problem with the order',
            ),
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              color: OrderDoneScreen._gray,
            ),
          ),
        ),
      ],
    );
  }
}

/// A "label … value" row of the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.16,
            color: OrderDoneScreen._gray,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}
