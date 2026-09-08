import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/features/request/presentation/chat_screen.dart';

ChatMessage message(int id, {bool read = false, bool mine = true}) =>
    ChatMessage(
      id: id,
      type: 'text',
      text: 'Message $id',
      time: '12:00',
      isMine: mine,
      isRead: read,
    );

void main() {
  test('receipt before send response is not lost', () {
    final result = mergeChatMessages([], [message(15)], readUpTo: 15);
    expect(result.single.isRead, isTrue);
  });
  test(
    'older REST snapshot cannot undo read receipt or remove live messages',
    () {
      final result = mergeChatMessages(
        [message(15, read: true), message(16)],
        [message(14), message(15)],
      );
      expect(result.map((m) => m.id), [14, 15, 16]);
      expect(result[1].isRead, isTrue);
    },
  );
  test('duplicate socket and REST messages are rendered once, in ID order', () {
    final result = mergeChatMessages(
      [message(2)],
      [message(3), message(2), message(1)],
    );
    expect(result.map((m) => m.id), [1, 2, 3]);
  });
  test('receipt boundary does not mark later or incoming messages read', () {
    final result = mergeChatMessages([], [
      message(14, mine: false),
      message(15),
      message(16),
    ], readUpTo: 15);
    expect(result.map((m) => m.isRead), [false, true, false]);
  });
}
