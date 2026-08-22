import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class CryptoService {
  CryptoService();

  final AesGcm _aes = AesGcm.with256bits();
  final Random _random = Random.secure();

  Uint8List generateSalt([int length = 32]) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  Future<SecretKey> deriveKey({
    required String masterPassword,
    required List<int> salt,
  }) async {
    final algorithm = Argon2id(
      memory: 32 * 1024,
      parallelism: 2,
      iterations: 3,
      hashLength: 32,
    );

    return algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(masterPassword)),
      nonce: salt,
    );
  }

  Future<String> encrypt({
    required String plainText,
    required SecretKey key,
  }) async {
    final nonce = _aes.newNonce();
    final secretBox = await _aes.encrypt(
      utf8.encode(plainText),
      secretKey: key,
      nonce: nonce,
    );

    final result = <String, String>{
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    return base64Encode(utf8.encode(jsonEncode(result)));
  }

  Future<String> decrypt({
    required String encryptedText,
    required SecretKey key,
  }) async {
    final decoded = utf8.decode(base64Decode(encryptedText));
    final data = jsonDecode(decoded) as Map<String, dynamic>;
    final secretBox = SecretBox(
      base64Decode(data['cipherText'] as String),
      nonce: base64Decode(data['nonce'] as String),
      mac: Mac(base64Decode(data['mac'] as String)),
    );

    final clearText = await _aes.decrypt(secretBox, secretKey: key);
    return utf8.decode(clearText);
  }
}
