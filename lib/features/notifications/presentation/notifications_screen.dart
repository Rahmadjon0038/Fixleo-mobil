import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/presentation/master_order_status_screen.dart';
import 'package:fixleo/features/master/presentation/master_request_detail_screen.dart';
import 'package:fixleo/features/notifications/data/notification_service.dart';
import 'package:fixleo/features/request/presentation/chat_screen.dart';
import 'package:fixleo/features/request/presentation/chats_list_screen.dart';
import 'package:fixleo/features/request/presentation/masters_responses_screen.dart';
import 'package:fixleo/features/request/presentation/order_status_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';

/// Real in-app notification inbox shared by clients and masters.
///
/// The backend stores notifications separately for each role. Opening the
/// inbox acknowledges the unread snapshot after it has been rendered, while
/// pull-to-refresh always fetches the latest server state.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.kind, this.service})
    : assert(kind == 'client' || kind == 'master');

  final String kind;

  /// Injectable so the feed and its read acknowledgement can be widget-tested
  /// without a network connection.
  final NotificationService? service;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _service =
      widget.service ?? NotificationService(kind: widget.kind);

  List<AppNotification> _items = const [];
  bool _loading = true;
  bool _markedInitialSnapshot = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });

      // The user has now seen the current inbox. Keep the unread dots visible
      // for this visit, but acknowledge them on the server so the bell badge is
      // cleared after returning to the previous screen.
      if (!_markedInitialSnapshot && items.any((item) => !item.isRead)) {
        _markedInitialSnapshot = true;
        try {
          await _service.markAllRead();
        } on Object {
          // Reading the feed must still work if acknowledgement temporarily
          // fails. A later visit will retry because the server rows stay unread.
          _markedInitialSnapshot = false;
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      final lang = LocaleController.language.value;
      setState(() {
        _error = tr(
          lang,
          'Bildirishnomalarni yuklab boʻlmadi',
          'Не удалось загрузить уведомления',
          'Could not load notifications',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Bildirishnomalar', 'Уведомления', 'Notifications'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: _content(lang),
      ),
    );
  }

  Widget _content(AppLanguage lang) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _placeholder(lang, _error!, retry: true);
    }
    if (_items.isEmpty) {
      return _placeholder(
        lang,
        tr(
          lang,
          'Hozircha bildirishnomalar yoʻq',
          'Пока нет уведомлений',
          'No notifications yet',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _NotificationCard(
          notification: _items[index],
          lang: lang,
          onTap: () => _open(_items[index]),
        ),
      ),
    );
  }

  /// Routes a tapped notification to the screen it's actually about, using
  /// the `orderId`/`conversationId` the backend already attaches to every
  /// event (see `AppNotification.data`) — previously these cards were purely
  /// decorative, with no way to act on them.
  void _open(AppNotification notification) {
    final isMaster = widget.kind == 'master';
    if (notification.type == 'chat_message') {
      final conversationId = notification.conversationId;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => conversationId != null
              ? ChatScreen(conversationId: conversationId, kind: widget.kind)
              : LiveChatsScreen(kind: widget.kind),
        ),
      );
      return;
    }
    final orderId = notification.orderId;
    if (orderId == null) return;
    if (!isMaster && notification.type == 'offer_received') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MastersResponsesScreen(orderId: orderId),
        ),
      );
    } else if (isMaster && notification.type == 'new_order_nearby') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MasterRequestDetailScreen(orderId: orderId),
        ),
      );
    } else if (isMaster) {
      // MasterOrdersScreen is bare tab content meant to sit inside
      // MasterHomeScreen's own Scaffold/SafeArea — pushed directly as its
      // own route it painted with no background/safe-area at all, showing
      // through to whatever the OS compositor had underneath. This is the
      // actual standalone, self-scaffolded per-order screen (client's
      // OrderTrackingScreen equivalent).
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MasterOrderStatusScreen(orderId: orderId),
        ),
      );
    } else if (notification.type == 'order_reopened') {
      // The order fell back to searching (master declined) — the client
      // still needs the map + "choose a master" flow, not a status timeline.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    } else {
      // Every other client-facing order type (on_the_way, arrived, work_done,
      // completed, cancelled, expired, ...) previously all landed on the same
      // read-only OrderTrackingScreen overview, with the notification's own
      // subject (e.g. "confirm completion") requiring one more tap to reach —
      // OrderStatusScreen is the focused, actionable screen for exactly that.
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: orderId)),
      );
    }
  }

  Widget _placeholder(AppLanguage lang, String message, {bool retry = false}) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),
          const Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: Color(0xFFB7C0CE),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF8D96A4)),
          ),
          if (retry) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _load,
                child: Text(tr(lang, 'Qayta urinish', 'Повторить', 'Retry')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.lang,
    required this.onTap,
  });

  final AppNotification notification;
  final AppLanguage lang;
  final VoidCallback onTap;

  IconData get _icon {
    final type = notification.type;
    if (type == 'chat_message') return Icons.chat_bubble_outline_rounded;
    if (type.contains('wallet') || type.contains('withdrawal')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (type.contains('complaint')) return Icons.gavel_outlined;
    if (type.contains('offer')) return Icons.handshake_outlined;
    if (type.contains('order') || type == 'new_order_nearby') {
      return Icons.receipt_long_outlined;
    }
    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: notification.isRead
          ? notification.title
          : tr(
              lang,
              'Oʻqilmagan: ${notification.title}',
              'Непрочитано: ${notification.title}',
              'Unread: ${notification.title}',
            ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: GlassCard.lite(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(_icon, size: 22, color: AppColors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 20 / 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          if (!notification.isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (notification.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _timeLabel(notification.createdAt, lang),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _timeLabel(DateTime? value, AppLanguage lang) {
    if (value == null) return '';
    final local = value.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.isNegative || diff.inMinutes < 1) {
      return tr(lang, 'Hozirgina', 'Только что', 'Just now');
    }
    if (diff.inMinutes < 60) {
      final n = diff.inMinutes;
      return tr(lang, '$n daqiqa oldin', '$n мин назад', '$n min ago');
    }
    if (diff.inHours < 24) {
      final n = diff.inHours;
      return tr(lang, '$n soat oldin', '$n ч назад', '$n h ago');
    }
    if (diff.inDays < 7) {
      final n = diff.inDays;
      return tr(lang, '$n kun oldin', '$n дн назад', '$n d ago');
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
