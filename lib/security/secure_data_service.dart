import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_service.dart';
import 'security_manager.dart';

class SecureDataService {
  SecureDataService({
    SecurityManager? securityManager,
    CryptoService? cryptoService,
  })  : _securityManager =
            securityManager ?? SecurityManager(),
        _cryptoService =
            cryptoService ?? CryptoService();

  final SecurityManager _securityManager;
  final CryptoService _cryptoService;

  Future<String> encrypt(String plainText) async {
    if (!_securityManager.isUnlocked) {
      throw StateError(
        'Security manager is locked.',
      );
    }

    final keyBytes = _securityManager.encryptionKey;

    try {
      final key = SecretKey(
        Uint8List.fromList(keyBytes),
      );

      return await _cryptoService.encrypt(
        plainText: plainText,
        key: key,
      );
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
    }
  }

  Future<String> decrypt(String encryptedText) async {
    if (!_securityManager.isUnlocked) {
      throw StateError(
        'Security manager is locked.',
      );
    }

    final keyBytes = _securityManager.encryptionKey;

    try {
      final key = SecretKey(
        Uint8List.fromList(keyBytes),
      );

      return await _cryptoService.decrypt(
        encryptedText: encryptedText,
        key: key,
      );
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
    }
  }
}
