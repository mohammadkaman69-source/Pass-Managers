import 'package:shared_preferences/shared_preferences.dart';

class PasswordService {

  static const String passwordKey = "master_password";
  static const String emailKey = "recovery_email";


  static Future<bool> hasPassword() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.containsKey(passwordKey);

  }


  static Future<void> saveCredentials(
    String password,
    String email,
  ) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      passwordKey,
      password,
    );

    await prefs.setString(
      emailKey,
      email,
    );

  }


  static Future<bool> checkPassword(
    String password,
  ) async {

    final prefs = await SharedPreferences.getInstance();

    final savedPassword =
        prefs.getString(passwordKey);


    return savedPassword == password;

  }


  static Future<String?> getRecoveryEmail() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(emailKey);

  }

}
