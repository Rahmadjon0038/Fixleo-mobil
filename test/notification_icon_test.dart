import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FCM uses a dedicated monochrome notification resource', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      matches(
        RegExp(
          r'default_notification_icon"\s+android:resource="@drawable/ic_stat_fixleo"',
        ),
      ),
    );
    final icon = File(
      'android/app/src/main/res/drawable/ic_stat_fixleo.xml',
    ).readAsStringSync();
    expect(icon, contains('android:width="24dp"'));
    expect(icon, contains('android:height="24dp"'));
    expect(RegExp(r'<path\b').allMatches(icon).length, 4);
    final colors = RegExp(
      r'android:fillColor="([^"]+)"',
    ).allMatches(icon).map((match) => match.group(1));
    expect(colors, everyElement('#FFFFFFFF'));
    expect(icon, isNot(contains('<background')));
    expect(icon, isNot(contains('ic_launcher')));
  });
}
