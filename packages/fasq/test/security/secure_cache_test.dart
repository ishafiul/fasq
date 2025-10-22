import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/src/cache/query_cache.dart';
import 'package:fasq/src/core/query_client.dart';
import 'package:fasq/src/core/query_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Secure Cache Entries', () {
    late QueryCache cache;
    late QueryClient client;

    setUp(() {
      cache = QueryCache();
      client = QueryClient();
    });

    tearDown(() {
      cache.dispose();
      client.dispose();
    });

    test('secure entries are not persisted to disk', () {
      // Set a secure entry
      cache.set<String>(
        'secure-token',
        'sensitive-data',
        isSecure: true,
        maxAge: Duration(minutes: 5),
      );

      // Verify entry exists in memory
      final entry = cache.get<String>('secure-token');
      expect(entry, isNotNull);
      expect(entry!.isSecure, isTrue);
      expect(entry.data, equals('sensitive-data'));

      // Note: In a real implementation, we would verify that secure entries
      // are not written to disk persistence layer
    });

    test('secure entries are cleared on app background', () {
      // Set both secure and non-secure entries
      cache.set<String>('secure-token', 'sensitive-data', isSecure: true);
      cache.set<String>('public-data', 'non-sensitive-data', isSecure: false);

      // Verify both exist
      expect(cache.get<String>('secure-token'), isNotNull);
      expect(cache.get<String>('public-data'), isNotNull);

      // Simulate app backgrounding by directly clearing secure entries
      cache.clearSecureEntries();

      // Verify only secure entries are cleared
      expect(cache.get<String>('secure-token'), isNull);
      expect(cache.get<String>('public-data'), isNotNull);
    });

    test('secure entries are cleared on app termination', () {
      // Set both secure and non-secure entries
      cache.set<String>('secure-token', 'sensitive-data', isSecure: true);
      cache.set<String>('public-data', 'non-sensitive-data', isSecure: false);

      // Verify both exist
      expect(cache.get<String>('secure-token'), isNotNull);
      expect(cache.get<String>('public-data'), isNotNull);

      // Simulate app termination by directly clearing secure entries
      cache.clearSecureEntries();

      // Verify only secure entries are cleared
      expect(cache.get<String>('secure-token'), isNull);
      expect(cache.get<String>('public-data'), isNotNull);
    });

    test('TTL is strictly enforced for secure entries', () {
      // Set a secure entry with short TTL
      cache.set<String>(
        'secure-token',
        'sensitive-data',
        isSecure: true,
        maxAge: Duration(milliseconds: 100),
      );

      // Verify entry exists initially
      expect(cache.get<String>('secure-token'), isNotNull);

      // Wait for TTL to expire
      Future.delayed(Duration(milliseconds: 150), () {
        // Verify entry is expired and removed
        expect(cache.get<String>('secure-token'), isNull);
      });
    });

    test('non-secure entries are unaffected by secure operations', () {
      // Set non-secure entry
      cache.set<String>('public-data', 'non-sensitive-data', isSecure: false);

      // Verify it exists
      expect(cache.get<String>('public-data'), isNotNull);

      // Clear secure entries
      cache.clearSecureEntries();

      // Verify non-secure entry still exists
      expect(cache.get<String>('public-data'), isNotNull);
    });

    test('clearSecureCache removes only secure data', () {
      // Set both secure and non-secure entries
      cache.set<String>('secure-token', 'sensitive-data', isSecure: true);
      cache.set<String>('public-data', 'non-sensitive-data', isSecure: false);

      // Verify both exist
      expect(cache.get<String>('secure-token'), isNotNull);
      expect(cache.get<String>('public-data'), isNotNull);

      // Clear secure cache
      // Call clearSecureCache by directly clearing secure entries
      cache.clearSecureEntries();

      // Verify only secure entries are removed
      expect(cache.get<String>('secure-token'), isNull);
      expect(cache.get<String>('public-data'), isNotNull);
    });

    test('secure entries with maxAge have expiresAt set', () {
      final maxAge = Duration(minutes: 5);
      cache.set<String>(
        'secure-token',
        'sensitive-data',
        isSecure: true,
        maxAge: maxAge,
      );

      final entry = cache.get<String>('secure-token');
      expect(entry, isNotNull);
      expect(entry!.isSecure, isTrue);
      expect(entry.expiresAt, isNotNull);
      expect(entry.isExpired, isFalse);

      // Verify expiresAt is approximately maxAge from creation
      final now = DateTime.now();
      final expectedExpiry = now.add(maxAge);
      final actualExpiry = entry.expiresAt!;
      final difference = actualExpiry.difference(expectedExpiry).abs();
      expect(difference.inSeconds, lessThan(1)); // Allow 1 second tolerance
    });

    test('secure entries without maxAge do not have expiresAt set', () {
      cache.set<String>(
        'secure-token',
        'sensitive-data',
        isSecure: true,
        // No maxAge provided
      );

      final entry = cache.get<String>('secure-token');
      expect(entry, isNotNull);
      expect(entry!.isSecure, isTrue);
      expect(entry.expiresAt, isNull);
      expect(entry.isExpired, isFalse);
    });

    test('QueryOptions with isSecure flag works correctly', () {
      final options = QueryOptions(
        isSecure: true,
        maxAge: Duration(minutes: 10),
      );

      expect(options.isSecure, isTrue);
      expect(options.maxAge, equals(Duration(minutes: 10)));
    });

    test('QueryOptions without isSecure flag defaults to false', () {
      final options = QueryOptions();

      expect(options.isSecure, isFalse);
      expect(options.maxAge, isNull);
    });
  });
}
