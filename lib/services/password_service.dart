import 'package:shared_preferences/shared_preferences.dart';

class PasswordService {

  static const String key = "master_password";

  static Future<bool> hasPassword() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.containsKey(key);
  }


  static Future<void> savePassword(String password) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(key, password);

  }


  static Future<bool> checkPassword(String password) async {

    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString(key);

    return saved == password;

  }

}
