import 'dart:typed_data';

class SecuritySession {
  Uint8List? _encryptionKey;

  bool get isUnlocked => _encryptionKey != null;

  Uint8List get encryptionKey {
    final key = _encryptionKey;

    if (key == null) {
      throw StateError('Security session is locked.');
    }

    return Uint8List.fromList(key);
  }

  void unlock(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError(
        'Encryption key must be exactly 32 bytes.',
      );
    }

    lock();

    _encryptionKey = Uint8List.fromList(key);
  }

  void lock() {
    final key = _encryptionKey;

    if (key != null) {
      key.fillRange(0, key.length, 0);
    }

    _encryptionKey = null;
  }
}
