import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/features/calls/presentation/call_screen.dart';

void main() {
  test('call duration is formatted with seconds and optional hours', () {
    expect(formatCallDuration(Duration.zero), '00:00');
    expect(formatCallDuration(const Duration(seconds: 9)), '00:09');
    expect(
      formatCallDuration(const Duration(minutes: 12, seconds: 34)),
      '12:34',
    );
    expect(
      formatCallDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  testWidgets('active call shows a live top timer and all audio controls', (
    tester,
  ) async {
    final call = CallService.instance;
    LocaleController.language.value = AppLanguage.uz;
    call.peerName.value = 'Hojiakbar QA';
    call.state.value = CallState.active;
    addTearDown(() {
      call.peerName.value = null;
      call.state.value = CallState.idle;
      LocaleController.language.value = AppLanguage.ru;
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: CallScreen()));

    expect(find.text('Hojiakbar QA'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byKey(const Key('call-mic')), findsOneWidget);
    expect(find.byKey(const Key('call-speaker')), findsOneWidget);
    expect(find.byKey(const Key('call-end')), findsOneWidget);
    await expectLater(
      find.byType(CallScreen),
      matchesGoldenFile('goldens/call_screen_active.png'),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('incoming call has clear accept and decline actions', (
    tester,
  ) async {
    final call = CallService.instance;
    LocaleController.language.value = AppLanguage.uz;
    call.peerName.value = 'Codex QA Client';
    call.state.value = CallState.incoming;
    addTearDown(() {
      call.peerName.value = null;
      call.state.value = CallState.idle;
      LocaleController.language.value = AppLanguage.ru;
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: CallScreen()));

    expect(find.text('Codex QA Client'), findsOneWidget);
    expect(find.text('Kiruvchi ovozli qoʻngʻiroq'), findsWidgets);
    expect(find.byKey(const Key('call-accept')), findsOneWidget);
    expect(find.byKey(const Key('call-decline')), findsOneWidget);
    expect(find.byKey(const Key('call-speaker')), findsNothing);
    await expectLater(
      find.byType(CallScreen),
      matchesGoldenFile('goldens/call_screen_incoming.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('busy call shows Line busy without active-call controls', (
    tester,
  ) async {
    final call = CallService.instance;
    LocaleController.language.value = AppLanguage.en;
    call.peerName.value = 'Busy Master';
    call.statusMessage.value = 'Line busy';
    call.state.value = CallState.busy;
    addTearDown(() {
      call.peerName.value = null;
      call.statusMessage.value = null;
      call.state.value = CallState.idle;
      LocaleController.language.value = AppLanguage.ru;
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: CallScreen()));

    expect(find.text('Busy Master'), findsOneWidget);
    expect(find.text('Line busy'), findsWidgets);
    expect(find.byKey(const Key('call-mic')), findsNothing);
    expect(find.byKey(const Key('call-speaker')), findsNothing);
    expect(find.byKey(const Key('call-end')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
