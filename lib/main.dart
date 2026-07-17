import 'package:flutter/material.dart';
import 'package:fixleo/app/app.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/auth_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore any persisted login so the user stays signed in across restarts.
  await AuthSession.instance.load();
  // Restore the last chosen language before the first frame is built.
  await LocaleController.load();
  runApp(const FixleoApp());
}
