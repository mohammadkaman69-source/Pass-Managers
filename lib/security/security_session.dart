import 'dart:typed_data';

class SecuritySession {
  SecuritySession._();

  static final SecuritySession instance =
      SecuritySession._();

  Uint8List? _encryptionKey;

  bool get isUnlocked =>
      _encryptionKey != null;

  Uint8List get encryptionKey {
    final key = _encryptionKey;

    if (key == null) {
      throw StateError(
        'Security session is locked.',
      );
    }

    return Uint8List.fromList(key);
  }

  void unlock(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError(
        'Encryption key must be 32 bytes.',
      );
    }

    _clearKey();

    _encryptionKey =
        Uint8List.fromList(key);
  }

  void lock() {
    _clearKey();
  }

  void _clearKey() {
    final key = _encryptionKey;

    if (key == null) {
      return;
    }

    key.fillRange(
      0,
      key.length,
      0,
    );

    _encryptionKey = null;
  }
}
