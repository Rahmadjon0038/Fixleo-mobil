import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/chat_service.dart' as api;
import 'package:fixleo/features/request/presentation/chats_list_screen.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_message_surface.dart';
import 'package:fixleo/features/request/presentation/widgets/chat_peer_avatar.dart';

class _Chats extends api.ChatService {
  _Chats({this.fail = false}) : super(kind: 'client');
  bool fail;
  @override
  Future<List<api.Conversation>> conversations() async {
    if (fail) throw const ApiException(message: 'Network unavailable');
    return const [
      api.Conversation(
        id: 1,
        orderId: 1,
        orderTitle: 'Repair',
        peerName: 'Akmal Karimov',
        lastMessageText: 'Ertaga kelaman',
      ),
      api.Conversation(
        id: 2,
        orderId: 2,
        orderTitle: 'Cleaning',
        peerName: 'Madina Aliyeva',
        lastMessageText: 'Rahmat',
      ),
    ];
  }
}

void main() {
  setUp(() => LocaleController.language.value = AppLanguage.uz);

  test('date labels handle today, yesterday and year boundaries', () {
    final now = DateTime(2026, 1, 1, 12);
    expect(chatDateLabel(now, AppLanguage.uz, now: now), 'Bugun');
    expect(
      chatDateLabel(DateTime(2025, 12, 31), AppLanguage.ru, now: now),
      'Вчера',
    );
    expect(
      chatDateLabel(DateTime(2025, 12, 30), AppLanguage.en, now: now),
      '30.12.2025',
    );
  });

  testWidgets('avatar uses name initials when photo is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatPeerAvatar(imageUrl: null, name: 'Akmal Karimov'),
        ),
      ),
    );
    expect(find.text('AK'), findsOneWidget);
  });

  testWidgets('live search filters name and last message as user types', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveChatsScreen(
            kind: 'client',
            showTitle: false,
            showBack: false,
            service: _Chats(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'akmal');
    await tester.pump();
    expect(find.text('Akmal Karimov'), findsOneWidget);
    expect(find.text('Madina Aliyeva'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Rahmat');
    await tester.pump();
    expect(find.text('Madina Aliyeva'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.text('Suhbat topilmadi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state can retry and recover', (tester) async {
    final service = _Chats(fail: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveChatsScreen(
            kind: 'client',
            showTitle: false,
            showBack: false,
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Network unavailable'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Qayta urinish'));
    await tester.pumpAndSettle();
    expect(find.text('Akmal Karimov'), findsOneWidget);
    expect(find.text('Network unavailable'), findsNothing);
  });

  testWidgets('long names and unread counts fit a narrow large-text screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 780),
            textScaler: TextScaler.linear(1.6),
          ),
          child: const Scaffold(
            body: ChatsList(
              conversations: [
                Conversation(
                  name: 'Murodillayev Hojiakbar juda uzun ism',
                  last: 'Xizmat haqidagi juda uzun xabar va tafsilotlar',
                  time: '12:30',
                  unread: 120,
                  online: true,
                  presence: 'onlayn',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('99+'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('message surfaces fit long text and expose read state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 780),
              textScaler: TextScaler.linear(1.5),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: const [
                ChatMessageSurface(
                  isMine: true,
                  isRead: true,
                  time: '10:35',
                  child: Text(
                    'Salom! Buyurtma bo‘yicha tafsilotlarni shu yerda kelishib olamiz.',
                  ),
                ),
                ChatMessageSurface(
                  isMine: false,
                  isRead: false,
                  time: '10:36',
                  child: Text('Yaxshi, rahmat!'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('O‘qilgan')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('optional visual preview uses the production chat surfaces', (
    tester,
  ) async {
    const output = String.fromEnvironment('CHAT_PREVIEW_PATH');
    if (output.isEmpty) return;
    // Optional local visual QA; ordinary CI tests do not depend on system fonts.
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('PreviewFont')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await tester.runAsync(loader.load);
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    await tester.binding.setSurfaceSize(const Size(430, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'PreviewFont'),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Chat · UI komponentlari',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(
                      height: 110,
                      child: ChatsList(
                        padding: EdgeInsets.zero,
                        conversations: [
                          Conversation(
                            name: 'Akmal Karimov',
                            last: 'Albatta, soat 10:00 da kelaman.',
                            time: '09:42',
                            unread: 2,
                            online: true,
                          ),
                        ],
                      ),
                    ),
                    ChatDateDivider(date: DateTime.now()),
                    const ChatMessageSurface(
                      isMine: false,
                      isRead: false,
                      time: '09:40',
                      child: Text(
                        'Assalomu alaykum! Qanday yordam kerak?',
                        style: TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ChatMessageSurface(
                      isMine: true,
                      isRead: true,
                      time: '09:41',
                      child: Text(
                        'Salom! Oshxonadagi kranni ta’mirlash kerak. Ertaga kela olasizmi?',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ChatMessageSurface(
                      isMine: false,
                      isRead: false,
                      time: '09:42',
                      child: Text(
                        'Albatta, soat 10:00 da kelaman.',
                        style: TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
