import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Anonymous per-install identifier used only to trace abusive OTP requests.
/// It contains no account, phone or hardware identifier and survives restarts.
class InstallationIdentity {
  InstallationIdentity._();

  static const _key = 'fixleo_installation_id';
  static String? _value;

  static String? get value => _value;

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_key)?.trim();
    if (existing?.isNotEmpty == true) {
      _value = existing;
      return;
    }
    final created = const Uuid().v4();
    await preferences.setString(_key, created);
    _value = created;
  }
}
