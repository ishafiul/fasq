import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitBreakerOpenException', () {
    test('can be instantiated with only a message', () {
      final exception = CircuitBreakerOpenException('Circuit is open');

      expect(exception, isA<Exception>());
      expect(exception.message, 'Circuit is open');
      expect(exception.circuitScope, isNull);
    });

    test('can be instantiated with message and circuit scope', () {
      const scope = 'api.example.com/users';
      final exception = CircuitBreakerOpenException(
        'Circuit breaker is open for endpoint',
        circuitScope: scope,
      );

      expect(exception, isA<Exception>());
      expect(exception.message, 'Circuit breaker is open for endpoint');
      expect(exception.circuitScope, scope);
    });

    test('toString returns meaningful representation without scope', () {
      final exception = CircuitBreakerOpenException('Circuit is open');

      expect(
        exception.toString(),
        'CircuitBreakerOpenException: Circuit is open',
      );
    });

    test('toString returns meaningful representation with scope', () {
      const scope = 'api.example.com/users';
      final exception = CircuitBreakerOpenException(
        'Circuit breaker is open for endpoint',
        circuitScope: scope,
      );

      expect(
        exception.toString(),
        'CircuitBreakerOpenException: Circuit breaker is open for endpoint (scope: $scope)',
      );
    });

    test('can be caught as Exception', () {
      Exception? caughtException;

      try {
        throw CircuitBreakerOpenException('Test exception');
      } on Exception catch (e) {
        caughtException = e;
      }

      expect(caughtException, isA<CircuitBreakerOpenException>());
      expect(
        (caughtException as CircuitBreakerOpenException).message,
        'Test exception',
      );
    });

    test('can be caught as CircuitBreakerOpenException', () {
      CircuitBreakerOpenException? caughtException;

      try {
        throw CircuitBreakerOpenException(
          'Test exception',
          circuitScope: 'test-scope',
        );
      } on CircuitBreakerOpenException catch (e) {
        caughtException = e;
      }

      expect(caughtException, isNotNull);
      expect(caughtException.message, 'Test exception');
      expect(caughtException.circuitScope, 'test-scope');
    });

    test('circuitScope attribute is accessible and holds correct value', () {
      const scope1 = 'api.example.com';
      const scope2 = 'api.other.com/path';

      final exception1 = CircuitBreakerOpenException(
        'Message 1',
        circuitScope: scope1,
      );
      final exception2 = CircuitBreakerOpenException(
        'Message 2',
        circuitScope: scope2,
      );

      expect(exception1.circuitScope, scope1);
      expect(exception2.circuitScope, scope2);
      expect(exception1.circuitScope, isNot(equals(exception2.circuitScope)));
    });

    test('message attribute is accessible and holds correct value', () {
      const message1 = 'First message';
      const message2 = 'Second message';

      final exception1 = CircuitBreakerOpenException(message1);
      final exception2 = CircuitBreakerOpenException(message2);

      expect(exception1.message, message1);
      expect(exception2.message, message2);
      expect(exception1.message, isNot(equals(exception2.message)));
    });

    test('can be instantiated with empty message', () {
      final exception = CircuitBreakerOpenException('');

      expect(exception.message, '');
      expect(exception.circuitScope, isNull);
    });

    test('can be instantiated with empty circuit scope', () {
      final exception = CircuitBreakerOpenException(
        'Message',
        circuitScope: '',
      );

      expect(exception.message, 'Message');
      expect(exception.circuitScope, '');
    });
  });
}
