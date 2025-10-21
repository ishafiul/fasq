import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/src/core/validation/input_validator.dart';
import 'package:fasq/src/core/query_options.dart';
import 'package:fasq/src/cache/query_cache.dart';
import 'package:fasq/src/core/query_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Input Validation', () {
    group('Query Key Validation', () {
      test('valid keys are accepted', () {
        final validKeys = [
          'user:123',
          'posts-list',
          'profile_data',
          'user123',
          'data:key:value',
          'test-key_123',
        ];

        for (final key in validKeys) {
          expect(() => InputValidator.validateQueryKey(key), returnsNormally);
        }
      });

      test('invalid keys are rejected with clear errors', () {
        // Test clearly invalid keys that should throw exceptions
        expect(
          () => InputValidator.validateQueryKey('user@123'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => InputValidator.validateQueryKey('key with spaces'),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => InputValidator.validateQueryKey('key.with.dots'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('empty key is rejected', () {
        expect(
          () => InputValidator.validateQueryKey(''),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Query key cannot be empty'),
          )),
        );
      });

      test('key too long is rejected', () {
        final longKey = 'a' * 256; // 256 characters
        expect(
          () => InputValidator.validateQueryKey(longKey),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Query key cannot exceed 255 characters'),
          )),
        );
      });
    });

    group('Cache Data Validation', () {
      test('valid data types are accepted', () {
        final validData = [
          'string',
          123,
          123.45,
          true,
          ['list', 'of', 'strings'],
          {'key': 'value', 'number': 42},
          null,
        ];

        for (final data in validData) {
          if (data == null) {
            expect(
              () => InputValidator.validateCacheData(data),
              throwsA(isA<ArgumentError>()),
            );
          } else {
            expect(
                () => InputValidator.validateCacheData(data), returnsNormally);
          }
        }
      });

      test('functions are rejected', () {
        expect(
          () => InputValidator.validateCacheData(() => 'test'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Cache data cannot be a function'),
          )),
        );
      });

      test('maps with function values are rejected', () {
        final mapWithFunction = {'key': () => 'value'};
        expect(
          () => InputValidator.validateCacheData(mapWithFunction),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Map values cannot be functions'),
          )),
        );
      });

      test('lists with function items are rejected', () {
        final listWithFunction = ['item1', () => 'item2'];
        expect(
          () => InputValidator.validateCacheData(listWithFunction),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('List items cannot be functions'),
          )),
        );
      });

      test('nested structures with functions are rejected', () {
        final nestedWithFunction = {
          'level1': {
            'level2': ['item1', () => 'item2']
          }
        };
        expect(
          () => InputValidator.validateCacheData(nestedWithFunction),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('List items cannot be functions'),
          )),
        );
      });
    });

    group('Duration Validation', () {
      test('valid durations are accepted', () {
        final validDurations = [
          Duration.zero,
          Duration(seconds: 1),
          Duration(minutes: 5),
          Duration(hours: 1),
          null,
        ];

        for (final duration in validDurations) {
          expect(() => InputValidator.validateDuration(duration, 'test'),
              returnsNormally);
        }
      });

      test('negative durations are rejected', () {
        expect(
          () => InputValidator.validateDuration(Duration(seconds: -1), 'test'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('test must be non-negative'),
          )),
        );
      });
    });

    group('QueryOptions Validation', () {
      test('valid options are accepted', () {
        final options = QueryOptions(
          enabled: true,
          staleTime: Duration(minutes: 5),
          cacheTime: Duration(minutes: 10),
          isSecure: false,
        );
        expect(() => InputValidator.validateOptions(options), returnsNormally);
      });

      test('secure options without maxAge are rejected', () {
        expect(
          () => QueryOptions(
            isSecure: true,
            // maxAge not provided
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('secure options with negative maxAge are rejected', () {
        expect(
          () => QueryOptions(
            isSecure: true,
            maxAge: Duration(seconds: -1),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Integration Tests', () {
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

      test('QueryClient validates inputs', () {
        // Valid query
        expect(
          () =>
              client.getQuery<String>('valid-key', () => Future.value('data')),
          returnsNormally,
        );

        // Invalid key
        expect(
          () => client.getQuery<String>(
              'invalid@key', () => Future.value('data')),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid options
        expect(
          () => client.getQuery<String>(
            'valid-key',
            () => Future.value('data'),
            options: QueryOptions(staleTime: Duration(seconds: -1)),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('QueryCache validates inputs', () {
        // Valid data
        expect(
          () => cache.set<String>('valid-key', 'data'),
          returnsNormally,
        );

        // Invalid key
        expect(
          () => cache.set<String>('invalid@key', 'data'),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid data (function)
        expect(
          () => cache.set<Function>('valid-key', () => 'data'),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid duration
        expect(
          () => cache.set<String>(
            'valid-key',
            'data',
            staleTime: Duration(seconds: -1),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('setQueryData validates inputs', () {
        // Valid data
        expect(
          () => client.setQueryData<String>('valid-key', 'data'),
          returnsNormally,
        );

        // Invalid key
        expect(
          () => client.setQueryData<String>('invalid@key', 'data'),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid data
        expect(
          () => client.setQueryData<Function>('valid-key', () => 'data'),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid maxAge
        expect(
          () => client.setQueryData<String>(
            'valid-key',
            'data',
            maxAge: Duration(seconds: -1),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Additional Validation Methods', () {
      test('validateString works correctly', () {
        // Valid strings
        expect(() => InputValidator.validateString('test', 'name'),
            returnsNormally);
        expect(
            () => InputValidator.validateString(null, 'name'), returnsNormally);

        // Empty string
        expect(
          () => InputValidator.validateString('', 'name'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('name cannot be empty'),
          )),
        );

        // Too long
        final longString = 'a' * 1001;
        expect(
          () => InputValidator.validateString(longString, 'name'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('name cannot exceed 1000 characters'),
          )),
        );
      });

      test('validateNumber works correctly', () {
        // Valid numbers
        expect(
            () => InputValidator.validateNumber(5, 'value'), returnsNormally);
        expect(() => InputValidator.validateNumber(null, 'value'),
            returnsNormally);

        // Below minimum
        expect(
          () => InputValidator.validateNumber(3, 'value', min: 5),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('value must be >= 5'),
          )),
        );

        // Above maximum
        expect(
          () => InputValidator.validateNumber(10, 'value', max: 5),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('value must be <= 5'),
          )),
        );
      });

      test('validateBoolean works correctly', () {
        // Valid booleans
        expect(() => InputValidator.validateBoolean(true, 'value'),
            returnsNormally);
        expect(() => InputValidator.validateBoolean(false, 'value'),
            returnsNormally);
        expect(() => InputValidator.validateBoolean(null, 'value'),
            returnsNormally);

        // Required but null
        expect(
          () => InputValidator.validateBoolean(null, 'value', required: true),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('value is required but was null'),
          )),
        );
      });
    });
  });
}
