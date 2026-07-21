import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/order_done_screen.dart';

/// The state of a single timeline step.
enum _StepState { done, current, pending }

/// One step in the order timeline.
class _Step {
  const _Step({required this.title, required this.subtitle, required this.state});

  final String title;
  final String subtitle;
  final _StepState state;
}

/// Order status — a vertical timeline tracking the order from acceptance
/// to completion. Steps are mock data for now.
class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key});

  static const _blue100 = Color(0xFFDBEAFE);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _text = Color(0xFF23232E);
  static const _muted = Color(0xFF9494A3);

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final steps = <_Step>[
      _Step(
        title: tr(lang, 'Buyurtma qabul qilindi', 'Заказ принят', 'Request accepted'),
        subtitle: tr(lang, 'Bugun, 14:05', 'Сегодня, 14:05', 'Today, 14:05'),
        state: _StepState.done,
      ),
      _Step(
        title: tr(lang, 'Usta yoʻlda', 'Мастер в пути', 'Master on the way'),
        subtitle: tr(lang, 'Bugun, 14:20', 'Сегодня, 14:20', 'Today, 14:20'),
        state: _StepState.done,
      ),
      _Step(
        title: tr(lang, 'Usta yetib keldi', 'Мастер прибыл', 'Master arrived'),
        subtitle: tr(lang, 'Kutilmoqda', 'Ожидается', 'Pending'),
        state: _StepState.current,
      ),
      _Step(
        title: tr(lang, 'Ish bajarildi', 'Работа выполнена', 'Work completed'),
        subtitle: tr(lang, 'Kutilmoqda', 'Ожидается', 'Pending'),
        state: _StepState.pending,
      ),
    ];
    return BrandedScaffold(
      title: tr(lang, 'Buyurtma holati', 'Статус заказа', 'Order status'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _timelineCard(steps),
                    const SizedBox(height: 10),
                    _noticeBanner(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // In the real product this screen advances automatically when the
            // master marks the job done (a backend/push event). Here a button
            // simulates that completion so the "order done" screen is reachable.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OrderDoneScreen(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Text(
                  tr(lang, 'Usta ishni yakunladi', 'Мастер завершил работу', 'The master finished the job'),
                  style: TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineCard(List<_Step> steps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++)
            _stepRow(steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }

  /// One timeline row: status marker + connector on the left, text on the right.
  Widget _stepRow(_Step step, {required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _marker(step.state),
            if (!isLast)
              Container(
                width: 3,
                height: 30,
                color: step.state == _StepState.done
                    ? AppColors.blue
                    : _slate200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  fontWeight: FontWeight.w700,
                  color: step.state == _StepState.pending ? _muted : _text,
                ),
              ),
              Text(
                step.subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The 26px circular marker for a step, varying by [state].
  Widget _marker(_StepState state) {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _slate200,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case _StepState.pending:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _slate200,
            borderRadius: BorderRadius.circular(13),
          ),
        );
    }
  }

  Widget _noticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        tr(
          LocaleController.language.value,
          'Holat oʻzgarganda bildirishnoma yuboramiz',
          'Мы отправим уведомление при изменении статуса',
          'We will notify you when the status changes',
        ),
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.16,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
