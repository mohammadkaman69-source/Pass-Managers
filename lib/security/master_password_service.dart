import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_service.dart';

class MasterPasswordService {
  MasterPasswordService({
    CryptoService? cryptoService,
    FlutterSecureStorage? secureStorage,
  })  : _cryptoService = cryptoService ?? CryptoService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final CryptoService _cryptoService;
  final FlutterSecureStorage _secureStorage;

  static const String _saltKey = 'master_password_salt';
  static const String _verificationKey = 'master_password_verification';

  static const String _verificationText =
      'pass_managers_master_password_verification_v1';

  Future<bool> isMasterPasswordConfigured() async {
    final salt = await _secureStorage.read(key: _saltKey);
    final verification =
        await _secureStorage.read(key: _verificationKey);

    return salt != null && verification != null;
  }

  Future<void> setupMasterPassword(
    String masterPassword,
  ) async {
    if (masterPassword.isEmpty) {
      throw ArgumentError('Master password cannot be empty.');
    }

    final alreadyConfigured =
        await isMasterPasswordConfigured();

    if (alreadyConfigured) {
      throw StateError(
        'Master password is already configured.',
      );
    }

    final salt = _cryptoService.generateSalt();

    final key = await _cryptoService.deriveKey(
      masterPassword: masterPassword,
      salt: salt,
    );

    final verification = await _cryptoService.encrypt(
      plainText: _verificationText,
      key: key,
    );

    await _secureStorage.write(
      key: _saltKey,
      value: base64Encode(salt),
    );

    await _secureStorage.write(
      key: _verificationKey,
      value: verification,
    );
  }

  Future<bool> verifyMasterPassword(
    String masterPassword,
  ) async {
    final saltValue =
        await _secureStorage.read(key: _saltKey);

    final verification =
        await _secureStorage.read(key: _verificationKey);

    if (saltValue == null || verification == null) {
      return false;
    }

    try {
      final salt = Uint8List.fromList(
        base64Decode(saltValue),
      );

      final key = await _cryptoService.deriveKey(
        masterPassword: masterPassword,
        salt: salt,
      );

      final decrypted =
          await _cryptoService.decrypt(
        encryptedText: verification,
        key: key,
      );

      return decrypted == _verificationText;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> deriveEncryptionKey(
    String masterPassword,
  ) async {
    final saltValue =
        await _secureStorage.read(key: _saltKey);

    if (saltValue == null) {
      throw StateError(
        'Master password is not configured.',
      );
    }

    final salt = Uint8List.fromList(
      base64Decode(saltValue),
    );

    final key = await _cryptoService.deriveKey(
      masterPassword: masterPassword,
      salt: salt,
    );

    final bytes = await key.extractBytes();

    return Uint8List.fromList(bytes);
  }

  Future<void> clearMasterPasswordConfiguration() async {
    await _secureStorage.delete(key: _saltKey);
    await _secureStorage.delete(
      key: _verificationKey,
    );
  }
}
