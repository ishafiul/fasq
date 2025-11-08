import 'dart:async';
import 'dart:convert';

import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _drainMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('QueryCache persistence', () {
    late _FakeSecurityPlugin plugin;

    setUp(() {
      plugin = _FakeSecurityPlugin();
    });

    tearDown(() {
      plugin.dispose();
    });

    test('persists non-secure entries across cache instances', () async {
      final cache1 = QueryCache(
        persistenceOptions: const PersistenceOptions(enabled: true),
        securityPlugin: plugin,
      );
      await cache1.persistenceInitialization;

      cache1.set<String>('user:1', 'alice');
      await _drainMicrotasks();

      expect(plugin.persistence.snapshot.containsKey('user:1'), isTrue);

      cache1.dispose();

      final cache2 = QueryCache(
        persistenceOptions: const PersistenceOptions(enabled: true),
        securityPlugin: plugin,
      );
      await cache2.persistenceInitialization;
      await _drainMicrotasks();

      final entry = cache2.get<String>('user:1');
      expect(entry, isNotNull);
      expect(entry!.data, 'alice');

      cache2.dispose();
    });

    test('does not persist secure entries', () async {
      final cache = QueryCache(
        persistenceOptions: const PersistenceOptions(enabled: true),
        securityPlugin: plugin,
      );
      await cache.persistenceInitialization;

      cache.set<String>(
        'secure-token',
        'sensitive',
        isSecure: true,
        maxAge: const Duration(minutes: 5),
      );
      await _drainMicrotasks();

      expect(plugin.persistence.snapshot.containsKey('secure-token'), isFalse);

      cache.dispose();
    });

    test('remove deletes persisted entry', () async {
      final cache = QueryCache(
        persistenceOptions: const PersistenceOptions(enabled: true),
        securityPlugin: plugin,
      );
      await cache.persistenceInitialization;

      cache.set<String>('session', 'value');
      await _drainMicrotasks();
      expect(plugin.persistence.snapshot.containsKey('session'), isTrue);

      cache.remove('session');
      await _drainMicrotasks();

      expect(plugin.persistence.snapshot.containsKey('session'), isFalse);

      cache.dispose();
    });

    test('clear removes persisted entries', () async {
      final cache = QueryCache(
        persistenceOptions: const PersistenceOptions(enabled: true),
        securityPlugin: plugin,
      );
      await cache.persistenceInitialization;

      cache.set<String>('a', '1');
      cache.set<String>('b', '2');
      await _drainMicrotasks();
      expect(plugin.persistence.snapshot.length, 2);

      cache.clear();
      await _drainMicrotasks();

      expect(plugin.persistence.snapshot, isEmpty);

      cache.dispose();
    });
  });
}

class _FakeSecurityPlugin implements SecurityPlugin {
  _FakeSecurityPlugin()
      : _storage = _FakeSecurityProvider(),
        _encryption = _FakeEncryptionProvider(),
        _persistence = _FakePersistenceProvider();

  final _FakeSecurityProvider _storage;
  final _FakeEncryptionProvider _encryption;
  final _FakePersistenceProvider _persistence;
  bool _initialized = false;

  _FakePersistenceProvider get persistence => _persistence;

  @override
  String get name => 'FakeSecurityPlugin';

  @override
  String get version => '1.0.0-test';

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  SecurityProvider createStorageProvider() {
    if (!_initialized) {
      throw StateError('Plugin not initialized');
    }
    return _storage;
  }

  @override
  EncryptionProvider createEncryptionProvider() {
    if (!_initialized) {
      throw StateError('Plugin not initialized');
    }
    return _encryption;
  }

  @override
  PersistenceProvider createPersistenceProvider() {
    if (!_initialized) {
      throw StateError('Plugin not initialized');
    }
    return _persistence;
  }

  void dispose() {
    _initialized = false;
  }
}

class _FakeSecurityProvider implements SecurityProvider {
  String? _key;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getEncryptionKey() async => _key;

  @override
  Future<void> setEncryptionKey(String key) async {
    _key = key;
  }

  @override
  Future<String> generateAndStoreKey() async {
    final key = base64Encode(
      utf8.encode('fake-key-${DateTime.now().microsecondsSinceEpoch}'),
    );
    _key = key;
    return key;
  }

  @override
  Future<void> deleteEncryptionKey() async {
    _key = null;
  }

  @override
  Future<bool> hasEncryptionKey() async => _key != null && _key!.isNotEmpty;

  @override
  bool get isSupported => true;
}

class _FakeEncryptionProvider implements EncryptionProvider {
  @override
  Future<List<int>> encrypt(List<int> data, String key) async =>
      List<int>.from(data);

  @override
  Future<List<int>> decrypt(List<int> data, String key) async =>
      List<int>.from(data);

  @override
  String generateKey() => base64Encode(utf8.encode('generated-key'));

  @override
  bool isValidKey(String key) => key.isNotEmpty;
}

class _FakePersistenceProvider implements PersistenceProvider {
  final Map<String, List<int>> _storage = {};

  Map<String, List<int>> get snapshot =>
      _storage.map((key, value) => MapEntry(key, List<int>.from(value)));

  @override
  Future<void> initialize() async {}

  @override
  Future<void> persist(String key, List<int> encryptedData) async {
    _storage[key] = List<int>.from(encryptedData);
  }

  @override
  Future<List<int>?> retrieve(String key) async => _storage[key];

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<bool> exists(String key) async => _storage.containsKey(key);

  @override
  Future<List<String>> getAllKeys() async => _storage.keys.toList();

  @override
  Future<Map<String, List<int>>> retrieveMultiple(List<String> keys) async {
    final result = <String, List<int>>{};
    for (final key in keys) {
      final value = _storage[key];
      if (value != null) {
        result[key] = List<int>.from(value);
      }
    }
    return result;
  }

  @override
  Future<void> persistMultiple(Map<String, List<int>> entries) async {
    entries.forEach((key, value) {
      _storage[key] = List<int>.from(value);
    });
  }

  @override
  Future<void> removeMultiple(List<String> keys) async {
    for (final key in keys) {
      _storage.remove(key);
    }
  }
}
