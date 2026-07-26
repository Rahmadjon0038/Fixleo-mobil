import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixleo/core/realtime/call_recording_retry_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late DateTime now;
  late CallRecordingRetryQueue queue;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('fixleo-call-retry-');
    now = DateTime.utc(2026, 7, 26, 12);
    queue = CallRecordingRetryQueue(
      now: () => now,
      supportDirectory: () async => temp,
      storageKeyPrefix: 'test_pending_call_recording:',
    );
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'failed recording remains durable until a successful completion',
    () async {
      final source = File('${temp.path}/fresh.m4a');
      await source.writeAsBytes(List<int>.generate(32, (index) => index));

      final item = await queue.persist(
        kind: 'client',
        ownerId: 7,
        callId: 91,
        sourcePath: source.path,
      );

      expect(await source.exists(), isFalse);
      expect(await File(item.path).exists(), isTrue);
      expect(await queue.pendingFor(kind: 'client', ownerId: 7), hasLength(1));
      // A different account can never see or upload this user's recording.
      expect(await queue.pendingFor(kind: 'client', ownerId: 8), isEmpty);

      final failed = await queue.markFailed(item);
      expect(failed.attempts, 1);
      expect(failed.nextAttemptAt, now.add(const Duration(seconds: 15)));
      expect(await File(item.path).exists(), isTrue);

      now = now.add(const Duration(seconds: 16));
      final retry = await queue.pendingFor(kind: 'client', ownerId: 7);
      expect(retry.single.attempts, 1);

      await queue.complete(retry.single);
      expect(await File(item.path).exists(), isFalse);
      expect(await queue.pendingFor(kind: 'client', ownerId: 7), isEmpty);
    },
  );
}
