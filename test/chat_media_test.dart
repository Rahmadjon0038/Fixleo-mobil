import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/features/request/data/chat_service.dart';
import 'package:fixleo/features/request/presentation/chats_list_screen.dart'
    as chat_list;
import 'package:fixleo/features/request/presentation/widgets/chat_media_message.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_presence_text.dart';
import 'package:fixleo/app/locale/app_locale.dart';

void main() {
  test('voice message parses media metadata and resolves a relative URL', () {
    final message = ChatMessage.fromJson({
      'id': 9,
      'sender': 'master',
      'type': 'voice',
      'audioUrl': '/api/v1/media/voice-9',
      'durationSec': 67,
      'fileMime': 'audio/mp4',
      'fileBytes': 48120,
      'createdAt': '2026-07-23T12:00:00.000Z',
    });

    expect(message.type, 'voice');
    expect(message.audioUrl, '${ApiConfig.baseUrl}/media/voice-9');
    expect(message.voiceDurationSec, 67);
    expect(message.fileMime, 'audio/mp4');
    expect(message.fileBytes, 48120);
  });

  test('image message keeps an absolute presigned URL', () {
    const url = 'http://localhost:9003/fixleo/chat/1/photo.jpg?signature=ok';
    final message = ChatMessage.fromJson({
      'id': 10,
      'sender': 'client',
      'type': 'image',
      'imageUrl': url,
    });

    expect(message.imageUrl, url);
    expect(message.audioUrl, isNull);
  });

  test('location message parses its point and readable address', () {
    final message = ChatMessage.fromJson({
      'id': 13,
      'sender': 'master',
      'type': 'location',
      'latitude': 41.311081,
      'longitude': 69.240562,
      'locationLabel': 'Toshkent, O‘zbekiston',
    });

    expect(message.type, 'location');
    expect(message.latitude, 41.311081);
    expect(message.longitude, 69.240562);
    expect(message.locationLabel, 'Toshkent, O‘zbekiston');
  });

  test('message parses the server read receipt timestamp', () {
    final unread = ChatMessage.fromJson({
      'id': 11,
      'sender': 'client',
      'type': 'text',
      'text': 'Unread',
      'readAt': null,
    });
    final read = ChatMessage.fromJson({
      'id': 12,
      'sender': 'client',
      'type': 'text',
      'text': 'Read',
      'readAt': '2026-07-26T09:30:00.000Z',
    });

    expect(unread.readAt, isNull);
    expect(read.readAt, DateTime.parse('2026-07-26T09:30:00.000Z'));
  });

  test('conversation parses and resolves the peer profile photo', () {
    final conversation = Conversation.fromJson({
      'id': 41,
      'orderId': 91,
      'orderTitle': 'Repair',
      'peer': {
        'name': 'Master',
        'avatarUrl': '/api/v1/profile-avatars/master/22?v=1',
        'online': true,
        'lastSeenAt': '2026-07-23T12:34:00.000Z',
      },
    });

    expect(
      conversation.peerAvatarUrl,
      '${ApiConfig.baseUrl}/profile-avatars/master/22?v=1',
    );
    expect(conversation.peerOnline, isTrue);
    expect(
      conversation.peerLastSeenAt,
      DateTime.parse('2026-07-23T12:34:00.000Z'),
    );
  });

  test('completed order conversation disables messages and calls', () {
    final conversation = Conversation.fromJson({
      'id': 42,
      'orderId': 92,
      'orderTitle': 'Completed repair',
      'orderStatus': 'completed',
      'writable': false,
      'canCall': false,
      'peer': {'name': 'Master', 'phone': null},
    });

    expect(conversation.orderStatus, 'completed');
    expect(conversation.writable, isFalse);
    expect(conversation.canCall, isFalse);
    expect(conversation.peerPhone, isNull);
  });

  test('presence label always includes online state and last seen', () {
    final lastSeen = DateTime(2026, 7, 23, 12, 34);
    final now = DateTime(2026, 7, 23, 18);

    expect(
      formatPresenceSummary(AppLanguage.uz, true, lastSeen, now: now),
      'onlayn · Oxirgi faollik: bugun 12:34',
    );
    expect(
      formatPresenceSummary(AppLanguage.ru, false, lastSeen, now: now),
      'не в сети · Был(а): сегодня 12:34',
    );
  });

  testWidgets(
    'chats list renders the peer avatar URL instead of a fixed icon',
    (tester) async {
      const avatarUrl =
          'http://localhost:9000/api/v1/profile-avatars/master/22?v=1';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: chat_list.ChatsList(
              conversations: [
                chat_list.Conversation(
                  name: 'Master',
                  last: 'Salom',
                  time: '12:00',
                  conversationId: 41,
                  avatarUrl: avatarUrl,
                ),
              ],
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
      expect((image.image as NetworkImage).url, avatarUrl);
    },
  );

  test('chat duration uses Telegram-like m:ss formatting', () {
    expect(formatChatDuration(0), '0:00');
    expect(formatChatDuration(7), '0:07');
    expect(formatChatDuration(67), '1:07');
  });
}
