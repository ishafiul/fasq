import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitBreakerOptions', () {
    test('initializes with default values', () {
      const options = CircuitBreakerOptions();

      expect(options.failureThreshold, 5);
      expect(options.resetTimeout, const Duration(seconds: 60));
      expect(options.successThreshold, 1);
      expect(options.ignoreExceptions, isEmpty);
    });

    test('initializes with custom values', () {
      final options = CircuitBreakerOptions(
        failureThreshold: 10,
        resetTimeout: const Duration(seconds: 30),
        successThreshold: 3,
        ignoreExceptions: [ArgumentError, StateError],
      );

      expect(options.failureThreshold, 10);
      expect(options.resetTimeout, const Duration(seconds: 30));
      expect(options.successThreshold, 3);
      expect(options.ignoreExceptions.length, 2);
    });

    test('copyWith creates new instance with updated values', () {
      const original = CircuitBreakerOptions();
      final updated = original.copyWith(
        failureThreshold: 10,
        resetTimeout: const Duration(seconds: 30),
      );

      expect(updated.failureThreshold, 10);
      expect(updated.resetTimeout, const Duration(seconds: 30));
      expect(updated.successThreshold, original.successThreshold);
      expect(updated.ignoreExceptions, original.ignoreExceptions);
    });

    test('copyWith preserves unchanged values', () {
      const original = CircuitBreakerOptions(
        failureThreshold: 5,
        resetTimeout: Duration(seconds: 60),
        successThreshold: 1,
      );

      final updated = original.copyWith(failureThreshold: 10);

      expect(updated.failureThreshold, 10);
      expect(updated.resetTimeout, original.resetTimeout);
      expect(updated.successThreshold, original.successThreshold);
    });

    group('isIgnored', () {
      test('returns false when ignoreExceptions is empty', () {
        const options = CircuitBreakerOptions();
        final exception = Exception('test');

        expect(options.isIgnored(exception), isFalse);
      });

      test('returns true for exact type match', () {
        final options = CircuitBreakerOptions(
          ignoreExceptions: [ArgumentError],
        );

        expect(options.isIgnored(ArgumentError('test')), isTrue);
        expect(options.isIgnored(StateError('test')), isFalse);
      });

      test('returns true for multiple ignored types', () {
        final options = CircuitBreakerOptions(
          ignoreExceptions: [ArgumentError, StateError],
        );

        expect(options.isIgnored(ArgumentError('test')), isTrue);
        expect(options.isIgnored(StateError('test')), isTrue);
        expect(options.isIgnored(Exception('test')), isFalse);
      });

      test('handles Exception base type', () {
        final options = CircuitBreakerOptions(
          ignoreExceptions: [Exception],
        );

        expect(options.isIgnored(Exception('test')), isTrue);
        expect(options.isIgnored(const FormatException('test')), isTrue);
        expect(options.isIgnored(StateError('test')), isFalse);
      });

      test('handles Error base type', () {
        final options = CircuitBreakerOptions(
          ignoreExceptions: [Error],
        );

        expect(options.isIgnored(StateError('test')), isTrue);
        expect(options.isIgnored(RangeError('test')), isTrue);
        expect(options.isIgnored(Exception('test')), isFalse);
      });

      test('handles specific exception types', () {
        final options = CircuitBreakerOptions(
          ignoreExceptions: [FormatException, ArgumentError],
        );

        expect(options.isIgnored(FormatException('test')), isTrue);
        expect(options.isIgnored(ArgumentError('test')), isTrue);
        expect(options.isIgnored(StateError('test')), isFalse);
      });
    });

    test('toString includes all fields', () {
      final options = CircuitBreakerOptions(
        failureThreshold: 10,
        resetTimeout: const Duration(seconds: 30),
        successThreshold: 3,
        ignoreExceptions: [ArgumentError, StateError],
      );

      final string = options.toString();

      expect(string, contains('CircuitBreakerOptions'));
      expect(string, contains('failureThreshold: 10'));
      expect(string, contains('resetTimeout: 30s'));
      expect(string, contains('successThreshold: 3'));
      expect(string, contains('ignoreExceptions: 2'));
    });

    test('handles minimum threshold value of 1', () {
      final options = CircuitBreakerOptions(
        failureThreshold: 1,
        successThreshold: 1,
      );

      expect(options.failureThreshold, 1);
      expect(options.successThreshold, 1);
    });

    test('handles large threshold values', () {
      final options = CircuitBreakerOptions(
        failureThreshold: 1000,
        successThreshold: 100,
      );

      expect(options.failureThreshold, 1000);
      expect(options.successThreshold, 100);
    });

    test('handles very short reset timeout', () {
      final options = CircuitBreakerOptions(
        resetTimeout: const Duration(milliseconds: 1),
      );

      expect(options.resetTimeout, const Duration(milliseconds: 1));
    });

    test('handles very long reset timeout', () {
      final options = CircuitBreakerOptions(
        resetTimeout: const Duration(hours: 24),
      );

      expect(options.resetTimeout, const Duration(hours: 24));
    });

    test('copyWith with null values preserves originals', () {
      const original = CircuitBreakerOptions(
        failureThreshold: 5,
        resetTimeout: Duration(seconds: 60),
        successThreshold: 1,
        ignoreExceptions: [ArgumentError],
      );

      final updated = original.copyWith();

      expect(updated.failureThreshold, original.failureThreshold);
      expect(updated.resetTimeout, original.resetTimeout);
      expect(updated.successThreshold, original.successThreshold);
      expect(updated.ignoreExceptions, original.ignoreExceptions);
    });

    test('copyWith with empty ignoreExceptions list', () {
      final original = CircuitBreakerOptions(
        ignoreExceptions: [ArgumentError, StateError],
      );

      final updated = original.copyWith(ignoreExceptions: []);

      expect(updated.ignoreExceptions, isEmpty);
    });

    test('isIgnored handles null-like edge cases', () {
      final options = CircuitBreakerOptions(
        ignoreExceptions: [Exception],
      );

      expect(options.isIgnored(Exception('')), isTrue);
      expect(options.isIgnored(StateError('')), isFalse);
    });
  });
}
