import 'package:flutter_test/flutter_test.dart';
import 'package:fasq_security/src/providers/crypto_encryption_provider.dart';
import 'package:fasq_security/src/exceptions/encryption_exception.dart';

void main() {
  group('CryptoEncryptionProvider', () {
    late CryptoEncryptionProvider provider;

    setUp(() {
      provider = CryptoEncryptionProvider();
    });

    group('encrypt and decrypt', () {
      test('encrypts and decrypts small data correctly', () async {
        final originalData = [1, 2, 3, 4, 5];
        final key = provider.generateKey();

        final encrypted = await provider.encrypt(originalData, key);
        final decrypted = await provider.decrypt(encrypted, key);

        expect(decrypted, equals(originalData));
      });

      test('encrypts and decrypts large data correctly', () async {
        // Create data larger than the threshold (50KB)
        final originalData = List.generate(60 * 1024, (i) => i % 256);
        final key = provider.generateKey();

        final encrypted = await provider.encrypt(originalData, key);
        final decrypted = await provider.decrypt(encrypted, key);

        expect(decrypted, equals(originalData));
      });

      test('throws exception for invalid key during encryption', () async {
        final data = [1, 2, 3, 4, 5];
        const invalidKey = 'invalid-key';

        expect(
          () => provider.encrypt(data, invalidKey),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('throws exception for invalid key during decryption', () async {
        final data = [1, 2, 3, 4, 5];
        const invalidKey = 'invalid-key';

        expect(
          () => provider.decrypt(data, invalidKey),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('different keys produce different encrypted data', () async {
        final originalData = [1, 2, 3, 4, 5];
        final key1 = provider.generateKey();
        final key2 = provider.generateKey();

        final encrypted1 = await provider.encrypt(originalData, key1);
        final encrypted2 = await provider.encrypt(originalData, key2);

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test(
        'same key produces different encrypted data for different inputs',
        () async {
          final data1 = [1, 2, 3, 4, 5];
          final data2 = [6, 7, 8, 9, 10];
          final key = provider.generateKey();

          final encrypted1 = await provider.encrypt(data1, key);
          final encrypted2 = await provider.encrypt(data2, key);

          expect(encrypted1, isNot(equals(encrypted2)));
        },
      );
    });

    group('key generation and validation', () {
      test('generates valid keys', () {
        final key = provider.generateKey();
        expect(provider.isValidKey(key), isTrue);
      });

      test('validates key format correctly', () {
        expect(provider.isValidKey(provider.generateKey()), isTrue);
        expect(provider.isValidKey('invalid-key'), isFalse);
        expect(provider.isValidKey(''), isFalse);
        expect(provider.isValidKey('short'), isFalse);
      });

      test('generates different keys each time', () {
        final key1 = provider.generateKey();
        final key2 = provider.generateKey();
        expect(key1, isNot(equals(key2)));
      });
    });

    group('edge cases', () {
      test('handles empty data', () async {
        final originalData = <int>[];
        final key = provider.generateKey();

        final encrypted = await provider.encrypt(originalData, key);
        final decrypted = await provider.decrypt(encrypted, key);

        expect(decrypted, equals(originalData));
      });

      test('handles single byte data', () async {
        final originalData = [42];
        final key = provider.generateKey();

        final encrypted = await provider.encrypt(originalData, key);
        final decrypted = await provider.decrypt(encrypted, key);

        expect(decrypted, equals(originalData));
      });

      test('handles data with zeros', () async {
        final originalData = [0, 1, 0, 2, 0, 3];
        final key = provider.generateKey();

        final encrypted = await provider.encrypt(originalData, key);
        final decrypted = await provider.decrypt(encrypted, key);

        expect(decrypted, equals(originalData));
      });
    });
  });
}
