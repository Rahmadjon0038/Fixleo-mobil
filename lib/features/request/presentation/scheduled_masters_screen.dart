import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/master_profile_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';

class ScheduledMastersScreen extends StatefulWidget {
  const ScheduledMastersScreen({
    super.key,
    required this.orderId,
    this.orderService,
  });
  final int orderId;
  final OrderService? orderService;

  @override
  State<ScheduledMastersScreen> createState() => _ScheduledMastersScreenState();
}

class _ScheduledMastersScreenState extends State<ScheduledMastersScreen> {
  late final OrderService _orders = widget.orderService ?? OrderService();
  List<ScheduledMasterOption> _masters = const [];
  OrderDetail? _order;
  bool _loading = true;
  bool _selecting = false;
  String? _waitingFor;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOrder());
  }

  Future<void> _load() async {
    try {
      final detailFuture = _orders.detail(widget.orderId);
      final masters = await _orders.scheduledMasters(widget.orderId);
      final order = await detailFuture;
      if (mounted) {
        setState(() {
          _masters = masters;
          _order = order;
          _waitingFor = order.invitationMasterName;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pollOrder() async {
    if (_waitingFor == null) return;
    try {
      final order = await _orders.detail(widget.orderId);
      if (!mounted) return;
      if (order.status == 'assigned' && order.master != null) {
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: widget.orderId),
          ),
        );
      } else if (order.invitationMasterName == null) {
        setState(() {
          _order = order;
          _waitingFor = null;
        });
        await _load();
      } else {
        setState(() {
          _order = order;
          _waitingFor = order.invitationMasterName;
        });
      }
    } catch (_) {}
  }

  Future<void> _select(ScheduledMasterOption master) async {
    if (_selecting || _waitingFor != null) return;
    setState(() => _selecting = true);
    try {
      final order = await _orders.selectScheduledMaster(
        widget.orderId,
        master.numericId,
      );
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _order = order;
        _waitingFor = order.invitationMasterName ?? master.name;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _selecting = false);
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      await _load();
    }
  }

  Future<void> _cancel() async {
    final lang = LocaleController.language.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          tr(
            lang,
            'Buyurtmani bekor qilasizmi?',
            'Отменить заказ?',
            'Cancel this order?',
          ),
        ),
        content: Text(
          tr(
            lang,
            'Tanlangan vaqt va yuborilgan taklif bekor qilinadi.',
            'Выбранное время и приглашение мастеру будут отменены.',
            'The selected time and master invitation will be cancelled.',
          ),
        ),
        actions: [
          LiquidActionButton.text(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr(lang, 'Yo‘q', 'Нет', 'Keep order')),
          ),
          LiquidActionButton.text(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr(lang, 'Ha, bekor qilish', 'Да, отменить', 'Cancel')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _selecting = true);
    try {
      await _orders.cancel(widget.orderId, reason: 'changed_mind');
      if (mounted) _home();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _selecting = false);
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      setState(() => _selecting = false);
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Buyurtmani bekor qilib bo‘lmadi',
              'Не удалось отменить заказ',
              'Could not cancel the order',
            ),
          ),
        ),
      );
    }
  }

  void _home() {
    _timer?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _money(int value) {
    final source = '$value';
    return source.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  }

  String _appointmentLabel(AppLanguage lang) {
    final scheduledAt = _order?.scheduledAt?.toLocal();
    if (scheduledAt != null) {
      final localizations = MaterialLocalizations.of(context);
      return '${localizations.formatMediumDate(scheduledAt)} · '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt), alwaysUse24HourFormat: true)}';
    }
    final date = _order?.scheduledDate;
    final slot = _order?.slotLabel;
    if (date != null && slot != null) return '$date · $slot';
    return date ?? slot ?? '—';
  }

  String _invitationCountdown(AppLanguage lang) {
    final expiresAt = _order?.invitationExpiresAt?.toLocal();
    if (expiresAt == null) return '';
    final seconds = expiresAt.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) {
      return tr(
        lang,
        'Vaqt tugamoqda…',
        'Время истекает…',
        'Time is expiring…',
      );
    }
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: BrandedScaffold(
        title: tr(
          lang,
          'Ustani tanlang',
          'Выберите мастера',
          'Choose a master',
        ),
        showBack: true,
        onBack: _home,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            children: [
              Expanded(child: _body(lang)),
              const SizedBox(height: 12),
              GlassButton(
                label: tr(
                  lang,
                  'Buyurtmani bekor qilish',
                  'Отменить заказ',
                  'Cancel order',
                ),
                variant: GlassButtonVariant.secondary,
                onPressed: _selecting ? null : _cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppLanguage lang) {
    if (_waitingFor != null) {
      return ListView(
        children: [
          if (_order != null) ...[
            _orderContextCard(lang),
            const SizedBox(height: 12),
          ],
          GlassCard(
            radius: 28,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                Text(
                  tr(
                    lang,
                    'Usta javobi kutilmoqda',
                    'Ждём ответа мастера',
                    'Waiting for the master',
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                if (_order?.invitationExpiresAt != null) ...[
                  const SizedBox(height: 14),
                  GlassContainer.lite(
                    borderRadius: 999,
                    tint: AppColors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _invitationCountdown(lang),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _waitingFor!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    lang,
                    'Usta 15 daqiqa ichida qabul qiladi yoki rad etadi',
                    'Мастер примет или отклонит заказ в течение 15 минут',
                    'The master has 15 minutes to accept or decline',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    lang,
                    'Javob bo‘lmasa, ustalar ro‘yxati avtomatik qaytadi.',
                    'Если ответа не будет, список мастеров откроется автоматически.',
                    'If there is no answer, the master list returns automatically.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: _masters.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 90),
                Icon(
                  Icons.event_busy_rounded,
                  size: 52,
                  color: AppColors.blue.withValues(alpha: .6),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(
                    lang,
                    'Bu vaqtda bo‘sh usta topilmadi',
                    'На это время свободных мастеров нет',
                    'No masters are free at this time',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    lang,
                    'Orqaga qaytib boshqa vaqtni tanlang',
                    'Вернитесь и выберите другое время',
                    'Go back and choose another time',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _masters.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) => index == 0
                  ? _orderContextCard(lang)
                  : index == 1
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: Text(
                        tr(
                          lang,
                          'Narx, reyting va sharhlarni solishtirib tanlang',
                          'Сравните цену, рейтинг и отзывы',
                          'Compare price, rating and reviews',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    )
                  : _masterCard(lang, _masters[index - 2]),
            ),
    );
  }

  Widget _orderContextCard(AppLanguage lang) {
    final order = _order;
    if (order == null) return const SizedBox.shrink();
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          _contextLine(Icons.event_available_rounded, _appointmentLabel(lang)),
          const SizedBox(height: 7),
          _contextLine(Icons.location_on_outlined, order.addressText),
        ],
      ),
    );
  }

  Widget _contextLine(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.blue),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF64748B), height: 1.35),
        ),
      ),
    ],
  );

  Widget _masterCard(AppLanguage lang, ScheduledMasterOption master) {
    void openProfile() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MasterProfileScreen(masterId: master.numericId),
      ),
    );
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: tr(
              lang,
              'Usta profilini ochish',
              'Открыть профиль',
              'Open profile',
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openProfile,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: master.avatarUrl == null
                        ? const ColoredBox(
                            color: Color(0xFFE8EFF7),
                            child: SizedBox(
                              width: 62,
                              height: 62,
                              child: Icon(
                                Icons.person_rounded,
                                color: AppColors.navy,
                              ),
                            ),
                          )
                        : Image.network(
                            master.avatarUrl!,
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 62,
                              height: 62,
                              child: Icon(Icons.person_rounded),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          master.name ?? tr(lang, 'Usta', 'Мастер', 'Master'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 10,
                          children: [
                            Text(
                              '★ ${master.ratingAvg?.toStringAsFixed(1) ?? '—'} (${master.ratingCount})',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${master.distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${master.completedOrders} ${tr(lang, 'ta ish', 'заказов', 'jobs')}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_money(master.price)} ${tr(lang, 'so‘m', 'сум', 'sum')}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
              ),
              LiquidActionButton.filled(
                onPressed: _selecting ? null : () => _select(master),
                child: Text(tr(lang, 'Tanlash', 'Выбрать', 'Choose')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
