import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitState', () {
    test('has three states: closed, open, halfOpen', () {
      expect(CircuitState.values.length, 3);
      expect(CircuitState.values, contains(CircuitState.closed));
      expect(CircuitState.values, contains(CircuitState.open));
      expect(CircuitState.values, contains(CircuitState.halfOpen));
    });

    test('closed state is accessible', () {
      const state = CircuitState.closed;
      expect(state, isNotNull);
      expect(state, CircuitState.closed);
    });

    test('open state is accessible', () {
      const state = CircuitState.open;
      expect(state, isNotNull);
      expect(state, CircuitState.open);
    });

    test('halfOpen state is accessible', () {
      const state = CircuitState.halfOpen;
      expect(state, isNotNull);
      expect(state, CircuitState.halfOpen);
    });

    test('states are distinct', () {
      expect(CircuitState.closed, isNot(CircuitState.open));
      expect(CircuitState.closed, isNot(CircuitState.halfOpen));
      expect(CircuitState.open, isNot(CircuitState.halfOpen));
    });
  });
}
