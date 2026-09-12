import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';
import 'package:fixleo/features/wallet/presentation/add_card_screen.dart';

class FakePayments extends PaymentService {
  int binds = 0;
  int confirmations = 0;
  String? number;
  String? expiry;
  String? code;
  Completer<Map<String, dynamic>>? pending;
  ApiException? failure;

  @override
  Future<Map<String, dynamic>> bindCard(String number, String expiry) async {
    binds++;
    this.number = number;
    this.expiry = expiry;
    if (failure != null) throw failure!;
    return pending?.future ??
        {'bindingId': 'binding-1', 'phone': '+998 ** *** 12 34'};
  }

  @override
  Future<SavedCard> confirmCard(String bindingId, String otp) async {
    confirmations++;
    code = otp;
    if (failure != null) throw failure!;
    return const SavedCard(id: 1, brand: 'humo', last4: '4364');
  }
}

Finder field(String name) => find.byKey(ValueKey('card-$name'));
PrimaryButton button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

Future<void> open(
  WidgetTester tester,
  FakePayments service, {
  double scale = 1,
  TargetPlatform platform = TargetPlatform.android,
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
      home: AddCardScreen(payments: service),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  await tester.enterText(field('number'), '9860090101014364');
  await tester.enterText(field('expiry'), '1229');
  await tester.pump();
}

void main() {
  setUp(() => LocaleController.language.value = AppLanguage.uz);

  testWidgets('formats PAN and expiry; no request until explicit submit', (
    tester,
  ) async {
    final service = FakePayments();
    await open(tester, service);
    expect(button(tester).onPressed, isNull);
    await fill(tester);
    expect(
      tester.widget<TextField>(field('number')).controller!.text,
      '9860 0901 0101 4364',
    );
    expect(tester.widget<TextField>(field('expiry')).controller!.text, '12/29');
    expect(button(tester).onPressed, isNotNull);
    expect(service.binds, 0);
    await tester.enterText(field('expiry'), '1399');
    await tester.pump();
    expect(button(tester).onPressed, isNull);
    expect(
      find.text('Kartadagi amal qilish muddatini tekshiring'),
      findsOneWidget,
    );
    await tester.enterText(field('expiry'), '0120');
    await tester.pump();
    expect(button(tester).onPressed, isNull);
  });

  testWidgets(
    'busy blocks duplicate requests; OTP clears PAN and supports autofill',
    (tester) async {
      final service = FakePayments()..pending = Completer();
      await open(tester, service);
      await fill(tester);
      final submit = button(tester).onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(service.binds, 1);
      expect(button(tester).onPressed, isNull);
      expect(tester.widget<TextField>(field('number')).enabled, isFalse);
      service.pending!.complete({'bindingId': 'binding-1', 'phone': '***1234'});
      await tester.pumpAndSettle();
      expect(field('number'), findsNothing);
      expect(find.text('••••  4364'), findsOneWidget);
      final otp = tester.widget<TextField>(field('otp'));
      expect(otp.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(button(tester).onPressed, isNull);
      expect(service.number, '9860090101014364');
      expect(service.expiry, '2912');
      await tester.enterText(field('otp'), '111111');
      await tester.pump();
      button(tester).onPressed!();
      await tester.pumpAndSettle();
      expect(service.confirmations, 1);
      expect(service.code, '111111');
    },
  );

  testWidgets('wrong OTP remains editable and does not request another SMS', (
    tester,
  ) async {
    final service = FakePayments();
    await open(tester, service);
    await fill(tester);
    button(tester).onPressed!();
    await tester.pumpAndSettle();
    service.failure = const ApiException(
      message: 'Kod noto‘g‘ri',
      statusCode: 400,
    );
    await tester.enterText(field('otp'), '123456');
    await tester.pump();
    button(tester).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Kod noto‘g‘ri'), findsOneWidget);
    expect(field('otp'), findsOneWidget);
    expect(service.binds, 1);
    expect(button(tester).onPressed, isNotNull);
  });

  testWidgets(
    'known shared-account cooldown blocks retry; disposal cancels timer',
    (tester) async {
      final service = FakePayments()
        ..failure = const ApiException(
          message:
              'Karta uchun kod yuborilgan. 60 soniyadan so‘ng qayta urinishingiz mumkin.',
          statusCode: 409,
        );
      await open(tester, service);
      await fill(tester);
      button(tester).onPressed!();
      await tester.pump();
      expect(button(tester).onPressed, isNull);
      expect(button(tester).label, contains('soniya kuting'));
      expect(service.binds, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unknown bank outcome never auto retries or pretends success', (
    tester,
  ) async {
    final service = FakePayments()
      ..failure = const ApiException(
        message:
            'Bank bilan aloqa yoki natija tekshirilmoqda. Amalni takrorlamang.',
        statusCode: 409,
      );
    await open(tester, service);
    await fill(tester);
    button(tester).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text(service.failure!.message), findsOneWidget);
    expect(service.binds, 1);
    expect(field('otp'), findsNothing);
  });

  testWidgets(
    'separator backspace and mid-string edits preserve digits and caret',
    (tester) async {
      await open(tester, FakePayments());
      final formatter = tester
          .widget<TextField>(field('expiry'))
          .inputFormatters!
          .single;
      final changed = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '12/29',
          selection: TextSelection.collapsed(offset: 3),
        ),
        const TextEditingValue(
          text: '1229',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(changed.text, '12/9');
      expect(changed.selection.baseOffset, 1);
      final paste = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '12/29',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(paste.text, '12/29');
      expect(paste.selection.baseOffset, 5);
    },
  );

  for (final lang in AppLanguage.values) {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('small viewport, keyboard and large text: $lang $platform', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        LocaleController.language.value = lang;
        final service = FakePayments();
        await open(tester, service, scale: 1.3, platform: platform);
        await fill(tester);
        expect(tester.takeException(), isNull);
        button(tester).onPressed!();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(PrimaryButton));
        await tester.pumpAndSettle();
        expect(find.byType(PrimaryButton).hitTestable(), findsOneWidget);
      });
    }
  }
}
