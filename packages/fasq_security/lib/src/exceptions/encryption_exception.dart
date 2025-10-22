/// Exception thrown when encryption/decryption operations fail.
class EncryptionException implements Exception {
  final String message;
  const EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}

