import 'dart:typed_data';

import 'master_password_service.dart';
import 'security_session.dart';

class SecurityManager {
  SecurityManager({
    MasterPasswordService? masterPasswordService,
    SecuritySession? securitySession,
  })  : _masterPasswordService =
            masterPasswordService ?? MasterPasswordService(),
        _securitySession =
            securitySession ?? SecuritySession();

  final MasterPasswordService _masterPasswordService;
  final SecuritySession _securitySession;

  bool get isUnlocked => _securitySession.isUnlocked;

  Future<bool> isMasterPasswordConfigured() {
    return _masterPasswordService.isMasterPasswordConfigured();
  }

  Future<void> setupMasterPassword(
    String masterPassword,
  ) async {
    await _masterPasswordService.setupMasterPassword(
      masterPassword,
    );

    final key =
        await _masterPasswordService.deriveEncryptionKey(
      masterPassword,
    );

    _securitySession.unlock(key);

    _clearBytes(key);
  }

  Future<bool> unlock(
    String masterPassword,
  ) async {
    final verified =
        await _masterPasswordService.verifyMasterPassword(
      masterPassword,
    );

    if (!verified) {
      return false;
    }

    final key =
        await _masterPasswordService.deriveEncryptionKey(
      masterPassword,
    );

    try {
      _securitySession.unlock(key);
      return true;
    } finally {
      _clearBytes(key);
    }
  }

  void lock() {
    _securitySession.lock();
  }

  Uint8List get encryptionKey {
    if (!_securitySession.isUnlocked) {
      throw StateError(
        'Security manager is locked.',
      );
    }

    return _securitySession.encryptionKey;
  }

  void _clearBytes(Uint8List bytes) {
    bytes.fillRange(0, bytes.length, 0);
  }
}
