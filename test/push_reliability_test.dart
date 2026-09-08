import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/core/notifications/push_delivery_policy.dart';
import 'package:fixleo/core/notifications/push_sync_retry.dart';
import 'package:fixleo/app/widgets/push_notification_banner.dart';

void main() {
  test(
    'deduplicates delivery and taps independently, but not matching bodies',
    () {
      final policy = PushDeliveryPolicy();
      final message = <String, dynamic>{'notificationId': '12'};
      expect(policy.acceptShown(message), isTrue);
      expect(policy.acceptShown(message), isFalse);
      expect(policy.acceptOpened(message), isTrue);
      expect(policy.acceptOpened(message), isFalse);
      expect(policy.acceptShown({'body': 'hello'}), isTrue);
      expect(policy.acceptShown({'body': 'hello'}), isTrue);
      policy.clear();
      expect(policy.acceptShown(message), isTrue);
    },
  );

  test('rejects delayed pushes for a different account or role', () {
    final policy = PushDeliveryPolicy();
    final message = <String, dynamic>{'ownerKind': 'master', 'ownerId': '8'};
    expect(policy.belongsTo(message, 'client', 8), isFalse);
    expect(policy.belongsTo(message, 'master', 9), isFalse);
    expect(policy.belongsTo(message, 'master', 8), isTrue);
    expect(policy.belongsTo({}, 'master', 8), isTrue);
  });

  test('dedup cache expires and stays bounded', () {
    var now = DateTime(2026);
    final policy = PushDeliveryPolicy(now: () => now);
    expect(policy.acceptShown({'notificationId': '1'}), isTrue);
    now = now.add(const Duration(minutes: 11));
    expect(policy.acceptShown({'notificationId': '1'}), isTrue);
    for (var i = 2; i < 140; i++) {
      policy.acceptShown({'notificationId': '$i'});
    }
    expect(policy.acceptShown({'notificationId': '1'}), isTrue);
  });

  testWidgets(
    'token registration coalesces calls and retries transient failure',
    (tester) async {
      var calls = 0;
      final first = Completer<bool>();
      final retry = PushSyncRetry(() {
        calls++;
        return calls == 1 ? first.future : Future.value(true);
      });
      final pending = retry.sync();
      final concurrent = retry.sync();
      expect(identical(pending, concurrent), isTrue);
      first.complete(false);
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 2);
      await tester.pump(const Duration(minutes: 5));
      expect(calls, 2);
      retry.reset();
    },
  );

  testWidgets('logout cancels retries, including an in-flight failure', (
    tester,
  ) async {
    var calls = 0;
    final first = Completer<bool>();
    final retry = PushSyncRetry(() {
      calls++;
      return first.future;
    });
    unawaited(retry.sync());
    retry.reset();
    first.complete(false);
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 1);
  });

  testWidgets('SDK exceptions do not escape and retries are capped', (
    tester,
  ) async {
    var calls = 0;
    final retry = PushSyncRetry(() async {
      calls++;
      throw StateError('offline');
    });
    await retry.sync();
    for (final delay in PushSyncRetry.delays) {
      await tester.pump(delay);
    }
    expect(calls, 6);
    await tester.pump(const Duration(hours: 1));
    expect(calls, 6);
    retry.reset();
  });

  testWidgets('banner enters, opens once on repeated tap, then dismisses', (
    tester,
  ) async {
    var opens = 0;
    var dismisses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PushNotificationBanner(
            title: 'New message',
            body: 'Your master is on the way.',
            onOpen: () => opens++,
            onDismiss: () => dismisses++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New message'));
    await tester.tap(find.text('New message'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(dismisses, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('banner dismisses upward without opening', (tester) async {
    var opens = 0;
    var dismisses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PushNotificationBanner(
            title: 'Status changed',
            body: 'Order accepted',
            onOpen: () => opens++,
            onDismiss: () => dismisses++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Dismissible), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(opens, 0);
    expect(dismisses, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('banner automatically dismisses and respects reduced motion', (
    tester,
  ) async {
    var dismisses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PushNotificationBanner(
              title: 'Update',
              body: '',
              onOpen: () {},
              onDismiss: () => dismisses++,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(dismisses, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
