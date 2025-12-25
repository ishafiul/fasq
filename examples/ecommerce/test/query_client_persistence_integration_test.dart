import 'dart:convert';
import 'dart:io';

import 'package:ecommerce/api/models/promotional_content_response.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Fake PathProvider
class FakePathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory _dir = Directory.systemTemp.createTempSync('fasq_test_');

  @override
  Future<String?> getApplicationSupportPath() async {
    return _dir.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _dir.path;
  }

  // Not part of interface, helper for cleanup
  void dispose() {
    if (_dir.existsSync()) {
      _dir.deleteSync(recursive: true);
    }
  }
}

// Fake SecureStorage
class FakeSecureStorage implements SecureStorageProvider {
  static final Map<String, String> _storage = {};

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<String?> getEncryptionKey() async {
    return _storage['fasq_key_id'];
  }

  @override
  Future<void> setEncryptionKey(String key) async {
    _storage['fasq_key_id'] = key;
  }

  @override
  Future<String> generateAndStoreKey() async {
    // Generate valid 32-byte key encoded in Base64
    final bytes = List<int>.generate(32, (i) => i % 256);
    final key = base64Encode(bytes);
    _storage['fasq_key_id'] = key;
    return key;
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<bool> hasEncryptionKey() async {
    return _storage.containsKey('fasq_key_id');
  }

  @override
  Future<void> deleteEncryptionKey() async {
    _storage.remove('fasq_key_id');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePathProviderPlatform fakePathProvider;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    fakePathProvider = FakePathProviderPlatform();
    PathProviderPlatform.instance = fakePathProvider;
  });

  tearDownAll(() {
    fakePathProvider.dispose();
  });

  test('QueryClient Persistence Cycle', () async {
    // Shared Secure Storage (Simulating device storage)
    final sharedStorage = FakeSecureStorage();

    // 1. Setup Security Plugin and Client (Session 1)
    final encryption1 = CryptoEncryptionProvider();
    final persistence1 = DriftPersistenceProvider();

    final plugin1 = DefaultSecurityPlugin(
      storageProvider: sharedStorage,
      encryptionProvider: encryption1,
      persistenceProvider: persistence1,
    );

    // Register Serializers
    final registry1 = registerQueryKeySerializers(const CacheDataCodecRegistry());

    final client1 = QueryClient(
      config: const CacheConfig(
        defaultStaleTime: Duration(minutes: 5),
        defaultCacheTime: Duration(minutes: 30),
      ),
      persistenceOptions: PersistenceOptions(
        enabled: true,
        codecRegistry: registry1,
      ),
      securityPlugin: plugin1,
    );

    await plugin1.initialize();
    await client1.cache.persistenceInitialization;

    // 2. Set Data
    final now = DateTime.now();
    final testData = [
      PromotionalContentResponse(
        id: '1',
        type: 'banner',
        title: 'Persisted Offer',
        description: 'Description',
        imageUrl: 'http://test.com/image.png',
        link: 'http://test.com',
        displayOrder: 1,
        startDate: now,
        endDate: now.add(const Duration(days: 1)),
        isActive: true,
        categoryIds: ['cat1'],
        createdAt: now,
        updatedAt: now,
        products: [],
      )
    ];

    print('Session 1: Setting query data...');
    client1.setQueryData(QueryKeys.currentOffers, testData);

    // Wait for persistence (async save)
    await Future.delayed(const Duration(seconds: 1));

    // Force close session 1 logic?
    await persistence1.dispose();
    print('Session 1 Closed. Persistence disposed.');

    // 3. Setup New Client (Session 2) - Simulating Restart
    // Re-use sharedStorage (so it has the encryption key)
    final encryption2 = CryptoEncryptionProvider();
    final persistence2 = DriftPersistenceProvider();

    final plugin2 = DefaultSecurityPlugin(
      storageProvider: sharedStorage,
      encryptionProvider: encryption2,
      persistenceProvider: persistence2,
    );

    final registry2 = registerQueryKeySerializers(const CacheDataCodecRegistry());

    // Reset Singleton for new session
    await QueryClient.resetForTesting();

    final client2 = QueryClient(
      config: const CacheConfig(
        defaultStaleTime: Duration(minutes: 5),
        defaultCacheTime: Duration(minutes: 30),
      ),
      persistenceOptions: PersistenceOptions(
        enabled: true,
        codecRegistry: registry2,
      ),
      securityPlugin: plugin2,
    );

    print('Session 2: Initializing...');
    await plugin2.initialize();
    await client2.cache.persistenceInitialization;
    print('Session 2: Persistence initialized.');

    // 4. Verify Data Restoration
    // Access cache directly to check state
    // Verify Data Restoration by checking result directly

    final restoredData = client2.getQueryData(QueryKeys.currentOffers);

    expect(restoredData, isNotNull, reason: 'Data should be restored from persistence');
    expect(restoredData!.length, 1);
    expect(restoredData.first.title, 'Persisted Offer');

    await persistence2.dispose();
  });
}
