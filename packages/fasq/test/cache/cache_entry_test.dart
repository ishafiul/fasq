import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CacheEntry', () {
    test('create factory sets timestamps', () {
      final entry = CacheEntry.create(
        data: 'test',
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 10),
      );

      expect(entry.data, 'test');
      expect(entry.createdAt, isNotNull);
      expect(entry.lastAccessedAt, isNotNull);
      expect(entry.accessCount, 1);
      expect(entry.staleTime, const Duration(minutes: 5));
      expect(entry.cacheTime, const Duration(minutes: 10));
    });

    test('age returns time since creation', () async {
      final entry = CacheEntry.create(
        data: 'test',
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 10),
      );

      expect(entry.age.inMilliseconds, greaterThanOrEqualTo(0));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(entry.age.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('isFresh returns true when age < staleTime', () {
      final entry = CacheEntry.create(
        data: 'test',
        staleTime: const Duration(hours: 1),
        cacheTime: const Duration(hours: 2),
      );

      expect(entry.isFresh, isTrue);
      expect(entry.isStale, isFalse);
    });

    test('isStale returns true when age >= staleTime', () {
      final now = DateTime.now();
      final oldTimestamp = now.subtract(const Duration(minutes: 10));

      final entry = CacheEntry<String>(
        data: 'test',
        createdAt: oldTimestamp,
        lastAccessedAt: oldTimestamp,
        accessCount: 1,
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 15),
      );

      expect(entry.isStale, isTrue);
      expect(entry.isFresh, isFalse);
    });

    test('shouldGarbageCollect when inactive and past cacheTime', () {
      final now = DateTime.now();
      final oldTimestamp = now.subtract(const Duration(minutes: 10));

      final entry = CacheEntry<String>(
        data: 'test',
        createdAt: oldTimestamp,
        lastAccessedAt: oldTimestamp,
        accessCount: 1,
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 8),
        referenceCount: 0,
      );

      expect(entry.shouldGarbageCollect(now), isTrue);
    });

    test('shouldGarbageCollect false when has active references', () {
      final now = DateTime.now();
      final oldTimestamp = now.subtract(const Duration(minutes: 10));

      final entry = CacheEntry<String>(
        data: 'test',
        createdAt: oldTimestamp,
        lastAccessedAt: oldTimestamp,
        accessCount: 1,
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 8),
        referenceCount: 1,
      );

      expect(entry.shouldGarbageCollect(now), isFalse);
    });

    test('estimateSize calculates size for string', () {
      final entry = CacheEntry.create(
        data: 'hello',
        staleTime: Duration.zero,
        cacheTime: const Duration(minutes: 5),
      );

      expect(entry.estimateSize(), 10);
    });

    test('estimateSize calculates size for list', () {
      final entry = CacheEntry.create(
        data: ['a', 'b', 'c'],
        staleTime: Duration.zero,
        cacheTime: const Duration(minutes: 5),
      );

      expect(entry.estimateSize(), greaterThan(0));
    });

    test('estimateSize calculates size for map', () {
      final entry = CacheEntry.create(
        data: {'key': 'value'},
        staleTime: Duration.zero,
        cacheTime: const Duration(minutes: 5),
      );

      expect(entry.estimateSize(), greaterThan(0));
    });

    test('estimateSize calculates size for numbers', () {
      final entry = CacheEntry.create(
        data: 42,
        staleTime: Duration.zero,
        cacheTime: const Duration(minutes: 5),
      );

      expect(entry.estimateSize(), 8);
    });

    test('with Access updates metadata', () {
      final entry = CacheEntry.create(
        data: 'test',
        staleTime: Duration.zero,
        cacheTime: const Duration(minutes: 5),
      );

      final accessed = entry.withAccess();

      expect(accessed.data, entry.data);
      expect(accessed.accessCount, entry.accessCount + 1);
      expect(accessed.lastAccessedAt.isAfter(entry.lastAccessedAt), isTrue);
    });

    test('copyWith creates new instance with updated fields', () {
      final entry = CacheEntry.create(
        data: 'test',
        staleTime: Duration.zero,
        cacheTime: const Duration(minutes: 5),
      );

      final updated = entry.copyWith(
        data: 'updated',
        accessCount: 10,
      );

      expect(updated.data, 'updated');
      expect(updated.accessCount, 10);
      expect(updated.createdAt, entry.createdAt);
    });

    test('toString includes relevant info', () {
      final entry = CacheEntry.create(
        data: 'test',
        staleTime: Duration.zero,
        cacheTime: const Duration(minutes: 5),
      );

      final string = entry.toString();

      expect(string, contains('CacheEntry'));
      expect(string, contains('age:'));
      expect(string, contains('accessCount:'));
    });
  });
}
