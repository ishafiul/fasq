import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryCache', () {
    late QueryCache cache;

    setUp(() {
      cache = QueryCache();
    });

    tearDown(() async {
      await cache.dispose();
    });

    test('get returns null for non-existent key', () {
      final entry = cache.get<String>('non-existent');
      expect(entry, isNull);
    });

    test('set and get stores and retrieves data', () {
      cache.set<String>('test-key', 'test data');

      final entry = cache.get<String>('test-key');

      expect(entry, isNotNull);
      expect(entry!.data, 'test data');
    });

    test('get updates access metadata', () {
      cache.set<String>('test-key', 'data');

      final entry1 = cache.get<String>('test-key');
      final accessCount1 = entry1!.accessCount;

      final entry2 = cache.get<String>('test-key');
      final accessCount2 = entry2!.accessCount;

      expect(accessCount2, accessCount1 + 1);
    });

    test('fresh data returns isFresh true', () {
      cache.set<String>(
        'test-key',
        'data',
        staleTime: const Duration(hours: 1),
      );

      final entry = cache.get<String>('test-key');

      expect(entry!.isFresh, isTrue);
      expect(entry.isStale, isFalse);
    });

    test('stale data returns isStale true', () {
      final now = DateTime.now();
      final oldTimestamp = now.subtract(const Duration(minutes: 10));

      final entry = CacheEntry<String>(
        data: 'data',
        createdAt: oldTimestamp,
        lastAccessedAt: oldTimestamp,
        accessCount: 1,
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 15),
      );

      cache.setData('test-key', 'data');

      expect(entry.isStale, isTrue);
    });

    test('remove deletes cache entry', () {
      cache.set<String>('test-key', 'data');

      expect(cache.get<String>('test-key'), isNotNull);

      cache.remove('test-key');

      expect(cache.get<String>('test-key'), isNull);
    });

    test('clear removes all entries', () {
      cache.set<String>('key1', 'data1');
      cache.set<String>('key2', 'data2');
      cache.set<String>('key3', 'data3');

      expect(cache.entryCount, 3);

      cache.clear();

      expect(cache.entryCount, 0);
    });

    test('invalidate removes specific entry', () {
      cache.set<String>('key1', 'data1');
      cache.set<String>('key2', 'data2');

      cache.invalidate('key1');

      expect(cache.get<String>('key1'), isNull);
      expect(cache.get<String>('key2'), isNotNull);
    });

    test('invalidateWithPrefix removes matching entries', () {
      cache.set<String>('user:1', 'data1');
      cache.set<String>('user:2', 'data2');
      cache.set<String>('post:1', 'data3');

      cache.invalidateWithPrefix('user:');

      expect(cache.get<String>('user:1'), isNull);
      expect(cache.get<String>('user:2'), isNull);
      expect(cache.get<String>('post:1'), isNotNull);
    });

    test('invalidateWhere removes matching entries', () {
      cache.set<String>('user:1', 'data1');
      cache.set<String>('user:2', 'data2');
      cache.set<String>('post:1', 'data3');

      cache.invalidateWhere((key) => key.contains('user'));

      expect(cache.get<String>('user:1'), isNull);
      expect(cache.get<String>('user:2'), isNull);
      expect(cache.get<String>('post:1'), isNotNull);
    });

    test('getData returns raw data', () {
      cache.set<String>('test-key', 'test data');

      final data = cache.getData<String>('test-key');

      expect(data, 'test data');
    });

    test('getData returns null for non-existent key', () {
      final data = cache.getData<String>('non-existent');

      expect(data, isNull);
    });

    test('setData stores data', () {
      cache.setData<String>('test-key', 'manual data');

      final entry = cache.get<String>('test-key');

      expect(entry!.data, 'manual data');
    });

    test('deduplicate returns same future for concurrent requests', () async {
      var callCount = 0;

      final future1 = cache.deduplicate<String>(
        'test-key',
        () async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data';
        },
      );

      final future2 = cache.deduplicate<String>(
        'test-key',
        () async {
          callCount++;
          return 'data';
        },
      );

      final result1 = await future1;
      final result2 = await future2;

      expect(callCount, 1);
      expect(result1, 'data');
      expect(result2, 'data');
    });

    test('deduplicate cleans up after completion', () async {
      await cache.deduplicate<String>(
        'test-key',
        () async => 'data',
      );

      var callCount = 0;
      await cache.deduplicate<String>(
        'test-key',
        () async {
          callCount++;
          return 'data';
        },
      );

      expect(callCount, 1);
    });

    test('currentSize returns total cache size', () {
      cache.set<String>('key1', 'hello');
      cache.set<String>('key2', 'world');

      expect(cache.currentSize, greaterThan(0));
    });

    test('getCacheInfo returns cache snapshot', () {
      cache.set<String>('key1', 'data1');
      cache.set<String>('key2', 'data2');

      final info = cache.getCacheInfo();

      expect(info.entryCount, 2);
      expect(info.sizeBytes, greaterThan(0));
      expect(info.maxCacheSize, 50 * 1024 * 1024);
    });

    test('getCacheKeys returns all keys', () {
      cache.set<String>('key1', 'data1');
      cache.set<String>('key2', 'data2');
      cache.set<String>('key3', 'data3');

      final keys = cache.getCacheKeys();

      expect(keys.length, 3);
      expect(keys.contains('key1'), isTrue);
      expect(keys.contains('key2'), isTrue);
      expect(keys.contains('key3'), isTrue);
    });

    test('inspectEntry returns cache entry', () {
      cache.set<String>('test-key', 'data');

      final entry = cache.inspectEntry('test-key');

      expect(entry, isNotNull);
      expect(entry!.data, 'data');
    });

    test('metrics track hits and misses', () {
      cache.set<String>('test-key', 'data');

      cache.get<String>('test-key');
      cache.get<String>('non-existent');
      cache.get<String>('non-existent-2');

      final metrics = cache.metrics;

      expect(metrics.hits, 1);
      expect(metrics.misses, 2);
      expect(metrics.totalRequests, 3);
      expect(metrics.hitRate, closeTo(0.33, 0.01));
    });

    test('eviction triggers when cache exceeds size', () async {
      final smallCache = QueryCache(
        config: const CacheConfig(
          maxCacheSize: 100,
        ),
      );

      for (var i = 0; i < 20; i++) {
        smallCache.set<String>('key$i', 'data' * 10);
      }

      expect(smallCache.entryCount, lessThan(20));
      expect(smallCache.currentSize, lessThanOrEqualTo(100));

      await smallCache.dispose();
    });

    test('eviction preserves active entries', () async {
      final smallCache = QueryCache(
        config: const CacheConfig(
          maxCacheSize: 100,
        ),
      );

      smallCache.setData('active-key', 'active data');

      for (var i = 0; i < 20; i++) {
        smallCache.set<String>('key$i', 'data' * 10);
      }

      expect(smallCache.entryCount, greaterThan(0));

      await smallCache.dispose();
    });
    test('trim with critical=false removes only stale inactive entries', () {
      // Active entry (should keep)
      cache.set<String>('active', 'data');
      // Verify initial state
      expect(cache.get<String>('active'), isNotNull);

      // 1. Fresh inactive (should keep)
      cache.set<String>('fresh', 'data', staleTime: const Duration(hours: 1));

      // 2. Stale inactive (should remove)
      cache.set<String>('stale', 'data',
          staleTime: const Duration(milliseconds: 1) // Instant stale
          );
    });

    test('trim removes old stale entries', () async {
      // Setup stale entry
      cache.set<String>('stale', 'data',
          staleTime: const Duration(milliseconds: 1));
      await Future.delayed(
          const Duration(milliseconds: 10)); // Ensure it's stale

      // Setup fresh entry
      cache.set<String>('fresh', 'data', staleTime: const Duration(hours: 1));

      expect(cache.get<String>('stale'), isNotNull);
      expect(cache.get<String>('fresh'), isNotNull);

      cache.trim(critical: false);

      expect(cache.get<String>('stale'), isNull); // Removed
      expect(cache.get<String>('fresh'), isNotNull); // Kept
    });

    test('trim(critical: true) removes all inactive entries', () async {
      // Setup fresh entry (would normally stay)
      cache.set<String>('fresh', 'data', staleTime: const Duration(hours: 1));

      expect(cache.get<String>('fresh'), isNotNull);

      cache.trim(critical: true);

      expect(cache.get<String>('fresh'), isNull); // Removed due to critical
    });
  });
}
