import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';
import 'package:fixleo/features/wallet/presentation/wallet_screen.dart';

class WalletPayments extends PaymentService {
  PendingTopup? pending;
  String status = 'pending';
  int balance = 2000;
  int checks = 0;
  int charges = 0;
  bool offline = false;
  Completer<PaymentAttempt?>? waiting;

  @override
  Future<int> walletBalance() async => balance;
  @override
  Future<List<WalletOperation>> walletOperations() async => [];
  @override
  Future<List<SavedCard>> cards() async => [
    const SavedCard(id: 7, brand: 'humo', last4: '1234'),
  ];
  @override
  Future<PendingTopup?> pendingTopup() async => pending;
  @override
  Future<PaymentAttempt?> refreshPendingTopup() async {
    checks++;
    if (waiting != null) return waiting!.future;
    if (offline) {
      throw const ApiException(message: 'Offline', isNetworkError: true);
    }
    if (status == 'succeeded' || status == 'failed') {
      pending = null;
      if (status == 'succeeded') balance = 3000;
    }
    return PaymentAttempt(operationId: 41, status: status);
  }

  @override
  Future<int> topup({
    required int cardId,
    required int amount,
    required String requestKey,
  }) async {
    charges++;
    pending = PendingTopup(
      key: requestKey,
      cardId: cardId,
      amount: amount,
      operationId: 41,
    );
    throw const TopupPendingException(message: 'Pending');
  }
}

const pending = PendingTopup(
  key: 'original-key',
  cardId: 7,
  amount: 1000,
  operationId: 41,
);

Future<void> open(
  WidgetTester tester,
  WalletPayments payments, {
  TargetPlatform platform = TargetPlatform.android,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: WalletScreen(payments: payments),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleController.language.value = AppLanguage.uz);

  testWidgets(
    'pending submission closes sheet and explains delay without an error toast',
    (tester) async {
      final payments = WalletPayments();
      await open(tester, payments);
      await tester.tap(find.text('Toʻldirish'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1000');
      await tester.tap(find.text('Toʻldirish').last);
      await tester.pumpAndSettle();
      expect(payments.charges, 1);
      expect(find.text('To‘lov tasdiqlanmoqda'), findsOneWidget);
      expect(find.textContaining('Qayta to‘lamang'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform pending status fits and completion refreshes balance automatically',
      (tester) async {
        final payments = WalletPayments()..pending = pending;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester, payments, platform: platform, scale: 1.3);
        expect(find.text('To‘lov tasdiqlanmoqda'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(payments.charges, 0);
        payments.status = 'succeeded';
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text('To‘lov tasdiqlanmoqda'), findsNothing);
        expect(find.text('3 000 soʻm'), findsOneWidget);
        expect(find.text('Hamyoningizga 1 000 so‘m qo‘shildi'), findsOneWidget);
        expect(payments.charges, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'offline status stays informative, resumes, and does not replay a debit',
    (tester) async {
      final payments = WalletPayments()
        ..pending = pending
        ..offline = true;
      await open(tester, payments);
      expect(find.textContaining('Aloqa tiklangach'), findsOneWidget);
      payments.offline = false;
      payments.status = 'failed';
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('To‘lov tasdiqlanmoqda'), findsNothing);
      expect(
        find.text('To‘lov amalga oshmadi. Holat yangilandi.'),
        findsOneWidget,
      );
      expect(payments.charges, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'no overlapping checks and no polling after dispose or in background',
    (tester) async {
      final payments = WalletPayments()..pending = pending;
      await open(tester, payments);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final count = payments.checks;
      await tester.pump(const Duration(seconds: 20));
      expect(payments.checks, count);
      payments.waiting = Completer<PaymentAttempt?>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(payments.checks, count + 1);
      await tester.pumpWidget(const SizedBox());
      payments.waiting!.complete(
        const PaymentAttempt(operationId: 41, status: 'pending'),
      );
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
      expect(payments.checks, count + 1);
    },
  );
}
