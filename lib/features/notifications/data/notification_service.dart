import 'package:fixleo/core/network/api_client.dart';

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.readAt,
    this.createdAt,
  });
  final int id;
  final String type;
  final String title;
  final String body;

  /// Free-form event payload the backend attaches per type — e.g.
  /// `{orderId: 12}` or `{conversationId: 3, orderId: 12}` — used to route a
  /// tap on the notification to the relevant screen.
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? createdAt;
  bool get isRead => readAt != null;

  int? get orderId => (data['orderId'] as num?)?.toInt();
  int? get conversationId => (data['conversationId'] as num?)?.toInt();

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: _int(j['id']),
    type: j['type'] as String? ?? '',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    data: (j['data'] as Map<String, dynamic>?) ?? const {},
    readAt: DateTime.tryParse(j['readAt']?.toString() ?? ''),
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
  );
}

/// In-app notification feed / bell (see docs/v3/ReviewsComplaints.md).
/// Same endpoints under `/clients/me/…` and `/masters/me/…`.
class NotificationService {
  NotificationService({required this.kind, ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final String kind; // 'client' | 'master'
  final ApiClient _client;

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final data = await _client.get(
      '/${kind}s/me/notifications',
      query: unreadOnly ? {'unread': 1} : null,
    );
    return (data as List<dynamic>)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> markAllRead() => _client.post('/${kind}s/me/notifications/read');
}
