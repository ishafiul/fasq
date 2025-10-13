import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryState', () {
    test('idle factory creates correct state', () {
      final state = QueryState<String>.idle();

      expect(state.status, QueryStatus.idle);
      expect(state.data, isNull);
      expect(state.error, isNull);
      expect(state.stackTrace, isNull);
      expect(state.isIdle, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.hasData, isFalse);
      expect(state.hasError, isFalse);
    });

    test('loading factory creates correct state', () {
      final state = QueryState<String>.loading();

      expect(state.status, QueryStatus.loading);
      expect(state.data, isNull);
      expect(state.error, isNull);
      expect(state.isLoading, isTrue);
      expect(state.hasData, isFalse);
    });

    test('loading factory with data creates correct state', () {
      final state = QueryState<String>.loading(data: 'cached data');

      expect(state.status, QueryStatus.loading);
      expect(state.data, 'cached data');
      expect(state.isLoading, isTrue);
      expect(state.hasData, isTrue);
    });

    test('success factory creates correct state', () {
      final state = QueryState<String>.success('data');

      expect(state.status, QueryStatus.success);
      expect(state.data, 'data');
      expect(state.error, isNull);
      expect(state.isSuccess, isTrue);
      expect(state.hasData, isTrue);
      expect(state.hasError, isFalse);
    });

    test('error factory creates correct state', () {
      final error = Exception('test error');
      final stackTrace = StackTrace.current;
      final state = QueryState<String>.error(error, stackTrace);

      expect(state.status, QueryStatus.error);
      expect(state.data, isNull);
      expect(state.error, error);
      expect(state.stackTrace, stackTrace);
      expect(state.hasError, isTrue);
      expect(state.hasData, isFalse);
    });

    test('error factory without stackTrace creates correct state', () {
      final error = Exception('test error');
      final state = QueryState<String>.error(error);

      expect(state.status, QueryStatus.error);
      expect(state.error, error);
      expect(state.stackTrace, isNull);
    });

    test('copyWith updates status', () {
      final state = QueryState<String>.idle();
      final updated = state.copyWith(status: QueryStatus.loading);

      expect(updated.status, QueryStatus.loading);
      expect(updated.data, isNull);
    });

    test('copyWith updates data', () {
      final state = QueryState<String>.idle();
      final updated = state.copyWith(data: 'new data');

      expect(updated.data, 'new data');
      expect(updated.status, QueryStatus.idle);
    });

    test('copyWith updates error', () {
      final state = QueryState<String>.idle();
      final error = Exception('error');
      final updated = state.copyWith(error: error);

      expect(updated.error, error);
      expect(updated.status, QueryStatus.idle);
    });

    test('copyWith updates multiple fields', () {
      final state = QueryState<String>.idle();
      final error = Exception('error');
      final updated = state.copyWith(
        status: QueryStatus.error,
        error: error,
      );

      expect(updated.status, QueryStatus.error);
      expect(updated.error, error);
    });

    test('equality works for identical states', () {
      final state1 = QueryState<String>.success('data');
      final state2 = QueryState<String>.success('data');

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('equality fails for different data', () {
      final state1 = QueryState<String>.success('data1');
      final state2 = QueryState<String>.success('data2');

      expect(state1, isNot(equals(state2)));
    });

    test('equality fails for different status', () {
      final state1 = QueryState<String>.idle();
      final state2 = QueryState<String>.loading();

      expect(state1, isNot(equals(state2)));
    });

    test('toString includes type and status info', () {
      final state = QueryState<String>.success('data');
      final string = state.toString();

      expect(string, contains('QueryState<String>'));
      expect(string, contains('success'));
      expect(string, contains('hasData: true'));
    });
  });
}

