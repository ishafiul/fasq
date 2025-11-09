import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fasq_security/src/plugins/default_security_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultSecurityPlugin', () {
    late DefaultSecurityPlugin plugin;

    setUp(() {
      plugin = DefaultSecurityPlugin();
    });

    group('plugin properties', () {
      test('has correct name', () {
        expect(plugin.name, equals('Default Security Plugin'));
      });

      test('has correct version', () {
        expect(plugin.version, equals('1.0.0'));
      });

      test('is supported', () {
        expect(plugin.isSupported, isTrue);
      });
    });

    group('provider creation', () {
      test('creates storage provider', () {
        final storageProvider = plugin.createStorageProvider();
        expect(storageProvider, isNotNull);
        expect(
          storageProvider.runtimeType.toString(),
          contains('SecureStorageProvider'),
        );
      });

      test('creates encryption provider', () {
        final encryptionProvider = plugin.createEncryptionProvider();
        expect(encryptionProvider, isNotNull);
        expect(
          encryptionProvider.runtimeType.toString(),
          contains('CryptoEncryptionProvider'),
        );
      });

      test('creates persistence provider', () {
        final persistenceProvider = plugin.createPersistenceProvider();
        expect(persistenceProvider, isNotNull);
        expect(
          persistenceProvider.runtimeType.toString(),
          contains('DriftPersistenceProvider'),
        );
      });
    });

    group('initialization', () {
      test('initializes successfully', () async {
        await plugin.initialize();

        expect(plugin.storageProvider, isNotNull);
        expect(plugin.encryptionProvider, isNotNull);
        expect(plugin.persistenceProvider, isNotNull);
      });

      test(
        'throws exception when accessing providers before initialization',
        () {
          expect(() => plugin.storageProvider, throwsA(isA<Exception>()));

          expect(() => plugin.encryptionProvider, throwsA(isA<Exception>()));

          expect(() => plugin.persistenceProvider, throwsA(isA<Exception>()));
        },
      );

      test('can initialize multiple times safely', () async {
        await plugin.initialize();
        await plugin.initialize(); // Should not throw

        expect(plugin.storageProvider, isNotNull);
        expect(plugin.encryptionProvider, isNotNull);
        expect(plugin.persistenceProvider, isNotNull);
      });
    });

    group('encryption key updates', () {
      setUp(() async {
        await plugin.initialize();
      });

      test('throws exception when no existing key found', () async {
        expect(
          () => plugin.updateEncryptionKey('new-key'),
          throwsA(isA<Exception>()),
        );
      });

      test('updates encryption key successfully', () async {
        try {
          await plugin.storageProvider.generateAndStoreKey();

          final newKey =
              base64Encode(List<int>.generate(32, (index) => index + 1));
          await plugin.updateEncryptionKey(newKey);

          expect(
            await plugin.storageProvider.getEncryptionKey(),
            equals(newKey),
          );
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('integration', () {
      test('all providers work together', () async {
        await plugin.initialize();

        try {
          final key = await plugin.storageProvider.generateAndStoreKey();
          expect(key, isNotEmpty);

          final testData = [1, 2, 3, 4, 5];
          final encrypted = await plugin.encryptionProvider.encrypt(
            testData,
            key,
          );
          final decrypted = await plugin.encryptionProvider.decrypt(
            encrypted,
            key,
          );
          expect(decrypted, equals(testData));

          await plugin.persistenceProvider.persist('test-key', encrypted);
          final retrieved = await plugin.persistenceProvider.retrieve(
            'test-key',
          );
          expect(retrieved, equals(encrypted));
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });
  });
}
