import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStorage {
  SecureKeyStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _saltKey = 'pass_managers_master_salt';
  static const String _verificationKey =
      'pass_managers_master_verification';

  Future<void> saveSalt(String salt) async {
    await _storage.write(
      key: _saltKey,
      value: salt,
    );
  }

  Future<String?> readSalt() async {
    return _storage.read(key: _saltKey);
  }

  Future<void> saveVerification(String verification) async {
    await _storage.write(
      key: _verificationKey,
      value: verification,
    );
  }

  Future<String?> readVerification() async {
    return _storage.read(key: _verificationKey);
  }

  Future<bool> isConfigured() async {
    final salt = await readSalt();
    final verification = await readVerification();

    return salt != null && verification != null;
  }

  Future<void> clear() async {
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _verificationKey);
  }
}
