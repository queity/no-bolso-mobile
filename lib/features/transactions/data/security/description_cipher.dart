import 'package:encrypt/encrypt.dart' as encryption;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM encryption for transaction descriptions at rest in Firestore.
/// The random key stays in this device's secure storage; it is not synced.
class DescriptionCipher {
  DescriptionCipher({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _keyName = 'transaction_description_aes_key_v1';
  static const _prefix = 'enc:v1:';

  final FlutterSecureStorage _secureStorage;

  Future<String?> encryptDescription(String? description) async {
    if (description == null || description.isEmpty) return description;

    final key = await _readOrCreateKey();
    final iv = encryption.IV.fromSecureRandom(12);
    final encrypter = encryption.Encrypter(
      encryption.AES(key, mode: encryption.AESMode.gcm),
    );
    final encrypted = encrypter.encrypt(description, iv: iv);
    return '$_prefix${iv.base64}:${encrypted.base64}';
  }

  Future<String?> decryptDescription(String? value) async {
    if (value == null || !value.startsWith(_prefix)) return value;

    final encoded = value.substring(_prefix.length).split(':');
    if (encoded.length != 2) {
      throw const FormatException('Descrição criptografada inválida.');
    }

    final storedKey = await _secureStorage.read(key: _keyName);
    if (storedKey == null) {
      throw StateError(
        'A chave local da descrição não está disponível neste dispositivo.',
      );
    }

    final key = encryption.Key.fromBase64(storedKey);
    final iv = encryption.IV.fromBase64(encoded[0]);
    final encrypted = encryption.Encrypted.fromBase64(encoded[1]);
    final encrypter = encryption.Encrypter(
      encryption.AES(key, mode: encryption.AESMode.gcm),
    );
    return encrypter.decrypt(encrypted, iv: iv);
  }

  Future<encryption.Key> _readOrCreateKey() async {
    final storedKey = await _secureStorage.read(key: _keyName);
    if (storedKey != null) return encryption.Key.fromBase64(storedKey);

    final key = encryption.Key.fromSecureRandom(32);
    await _secureStorage.write(key: _keyName, value: key.base64);
    return key;
  }
}
