import 'package:fixleo/core/network/api_client.dart';

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.readAt,
    this.createdAt,
  });
  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;
  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: _int(j['id']),
    type: j['type'] as String? ?? '',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
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
