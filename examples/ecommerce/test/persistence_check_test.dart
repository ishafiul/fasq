import 'dart:convert';
import 'package:ecommerce/api/models/promotional_content_response.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Persistence Save and Restore Check', () async {
    // 1. Setup Provider
    final provider = DriftPersistenceProvider();
    await provider.initialize();

    // 2. Create Test Data
    final key = QueryKeys.currentOffers.key;
    final now = DateTime.now();
    final testData = [
      PromotionalContentResponse(
        id: '1',
        type: 'banner',
        title: 'Test Offer',
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

    // 3. Serialize and Save
    // Register serializers
    final registry = registerQueryKeySerializers(const CacheDataCodecRegistry());

    print('Registered Keys: ${registry.serializers.keys.toList()}');
    final serializer = registry.serializers['List<PromotionalContentResponse>'];
    expect(serializer, isNotNull, reason: 'Serializer for List<PromotionalContentResponse> not found');

    // Simulate encoding:
    // 1. Serializer (List<T> -> List<Map>)
    final serializedObject = serializer!.encode(testData);
    // 2. JSON Encode (Object -> String)
    final jsonString = jsonEncode(serializedObject);
    // 3. UTF8 Encode (String -> List<int>) - Simulating "encryption" input
    final bytes = utf8.encode(jsonString);

    // Save to persistence
    await provider.persist(
      key,
      bytes,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    print('Saved to persistence.');

    // 4. Verify Existence
    final exists = await provider.exists(key);
    expect(exists, isTrue, reason: 'Key should exist in persistence');

    // 5. Restore
    final restoredBytes = await provider.retrieve(key);
    expect(restoredBytes, isNotNull, reason: 'Should return cached entry');

    // 6. Deserialize
    final restoredString = utf8.decode(restoredBytes!);
    final restoredObject = jsonDecode(restoredString);
    final restoredData = serializer.decode(restoredObject);

    expect(restoredData, isNotEmpty);
    expect(restoredData.first.title, 'Test Offer');

    print('Restored Data: $restoredData');

    await provider.dispose();
  });
}
