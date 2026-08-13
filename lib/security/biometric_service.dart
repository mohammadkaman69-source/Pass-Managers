import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'security_session.dart';

class BiometricService {
  BiometricService({
    LocalAuthentication? localAuthentication,
    FlutterSecureStorage? secureStorage,
  })  : _auth = localAuthentication ?? LocalAuthentication(),
        _storage = secureStorage ?? const FlutterSecureStorage();

  static const _enabledKey = 'biometric_unlock_enabled';
  static const _keyKey = 'biometric_unlock_key_v1';

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  Future<bool> isSupported() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    return (await _storage.read(key: _enabledKey)) == 'true';
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> enable() async {
    if (!await isSupported()) {
      return false;
    }

    final authenticated = await _authenticate();
    if (!authenticated) {
      return false;
    }

    final key = SecuritySession.instance.encryptionKey;
    try {
      await _storage.write(
        key: _keyKey,
        value: base64Encode(key),
      );
      await _storage.write(
        key: _enabledKey,
        value: 'true',
      );
      return true;
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<void> disable() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _keyKey);
  }

  Future<bool> authenticateAndUnlock() async {
    if (!await isEnabled()) {
      return false;
    }

    final authenticated = await _authenticate();
    if (!authenticated) {
      return false;
    }

    final encoded = await _storage.read(key: _keyKey);
    if (encoded == null || encoded.isEmpty) {
      await disable();
      return false;
    }

    try {
      final key = base64Decode(encoded);
      SecuritySession.instance.unlock(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'برای ورود به Pass Managers احراز هویت کنید.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
