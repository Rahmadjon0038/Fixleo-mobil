/// Bounded, session-local deduplication. A tap is independent of presentation:
/// showing a foreground banner must never consume the user's later tap.
class PushDeliveryPolicy {
  PushDeliveryPolicy({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _shown = <String, DateTime>{};
  final _opened = <String, DateTime>{};
  static const _retention = Duration(minutes: 10);
  static const _capacity = 128;

  bool belongsTo(Map<String, dynamic> data, String role, int? ownerId) {
    final targetRole = data['ownerKind']?.toString();
    final targetId = data['ownerId']?.toString();
    return (targetRole == null || targetRole == role) &&
        (targetId == null || targetId == ownerId?.toString());
  }

  bool acceptShown(Map<String, dynamic> data) => _accept(_shown, data);
  bool acceptOpened(Map<String, dynamic> data) => _accept(_opened, data);

  bool _accept(Map<String, DateTime> seen, Map<String, dynamic> data) {
    final id = data['notificationId'] ?? data['_remoteMessageId'];
    // Do not deduplicate by body: two legitimate chat messages can be equal.
    if (id == null || id.toString().isEmpty) return true;
    final now = _now();
    seen.removeWhere((_, time) => now.difference(time) >= _retention);
    final key = '${data['ownerKind']}:${data['ownerId']}:$id';
    if (seen.containsKey(key)) return false;
    if (seen.length >= _capacity) seen.remove(seen.keys.first);
    seen[key] = now;
    return true;
  }

  void clear() {
    _shown.clear();
    _opened.clear();
  }
}
