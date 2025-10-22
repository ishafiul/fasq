/// Abstract interface for encryption/decryption operations.
///
/// Implementations should provide secure encryption algorithms
/// like AES-GCM for encrypting cache data.
abstract class EncryptionProvider {
  /// Encrypts data using the provided key.
  ///
  /// [data] The data to encrypt as bytes
  /// [key] The encryption key
  /// Returns the encrypted data as bytes
  Future<List<int>> encrypt(List<int> data, String key);

  /// Decrypts data using the provided key.
  ///
  /// [data] The encrypted data as bytes
  /// [key] The encryption key
  /// Returns the decrypted data as bytes
  Future<List<int>> decrypt(List<int> data, String key);

  /// Generates a new encryption key.
  ///
  /// Returns a cryptographically secure encryption key.
  String generateKey();

  /// Validates that a key is properly formatted.
  ///
  /// [key] The key to validate
  /// Returns true if the key is valid, false otherwise
  bool isValidKey(String key);
}

