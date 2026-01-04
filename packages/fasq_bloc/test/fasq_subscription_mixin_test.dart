import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:fasq/fasq.dart';
import 'package:fasq_bloc/src/mixins/fasq_subscription_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FasqSubscriptionMixin', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    test('initializes with empty subscriptions set', () {
      final cubit = _TestCubit();

      expect(cubit.subscriptionCount, 0);
    });

    test('subscribeToQuery adds subscription for valid query', () async {
      final cubit = _TestCubit();
      final query = QueryClient().getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async => 'data',
      );

      cubit.subscribeToQuery<String>(
        query,
        (state) => cubit.emit(state),
      );

      expect(cubit.subscriptionCount, 1);
      await cubit.close();
    });

    test('subscribeToQuery does nothing for null query', () {
      final cubit = _TestCubit();

      cubit.subscribeToQuery<String>(
        null,
        (state) => cubit.emit(state),
      );

      expect(cubit.subscriptionCount, 0);
    });

    test('subscribeToQuery receives state updates from query stream', () async {
      final cubit = _TestCubit();
      final query = QueryClient().getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async => 'test data',
      );

      final states = <QueryState<String>>[];
      cubit.subscribeToQuery<String>(
        query,
        (state) {
          states.add(state);
          if (!cubit.isClosed) {
            cubit.emit(state);
          }
        },
      );

      await query.fetch();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(states.length, greaterThan(0));
      final successState = states.firstWhere(
        (s) => s.status == QueryStatus.success,
        orElse: () => states.last,
      );
      expect(successState.data, 'test data');
      expect(successState.status, QueryStatus.success);

      await cubit.close();
    });

    test('can subscribe to multiple queries', () async {
      final cubit = _TestCubit();
      final query1 = QueryClient().getQuery<String>(
        'key1'.toQueryKey(),
        queryFn: () async => 'data1',
      );
      final query2 = QueryClient().getQuery<String>(
        'key2'.toQueryKey(),
        queryFn: () async => 'data2',
      );

      cubit.subscribeToQuery<String>(
        query1,
        (state) => cubit.emit(state),
      );
      cubit.subscribeToQuery<String>(
        query2,
        (state) => cubit.emit(state),
      );

      expect(cubit.subscriptionCount, 2);
      await cubit.close();
    });

    test('close() cancels all subscriptions', () async {
      final cubit = _TestCubit();
      final query1 = QueryClient().getQuery<String>(
        'key1'.toQueryKey(),
        queryFn: () async => 'data1',
      );
      final query2 = QueryClient().getQuery<String>(
        'key2'.toQueryKey(),
        queryFn: () async => 'data2',
      );

      final subscription1Cancelled = Completer<bool>();
      final subscription2Cancelled = Completer<bool>();

      cubit.subscribeToQuery<String>(
        query1,
        (state) {
          if (cubit.isClosed) {
            subscription1Cancelled.complete(true);
          }
          cubit.emit(state);
        },
      );
      cubit.subscribeToQuery<String>(
        query2,
        (state) {
          if (cubit.isClosed) {
            subscription2Cancelled.complete(true);
          }
          cubit.emit(state);
        },
      );

      expect(cubit.subscriptionCount, 2);

      await cubit.close();

      expect(cubit.subscriptionCount, 0);
    });

    test('close() clears subscriptions set', () async {
      final cubit = _TestCubit();
      final query = QueryClient().getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async => 'data',
      );

      cubit.subscribeToQuery<String>(
        query,
        (state) => cubit.emit(state),
      );

      expect(cubit.subscriptionCount, 1);

      await cubit.close();

      expect(cubit.subscriptionCount, 0);
    });

    test('does not emit state after cubit is closed', () async {
      final cubit = _TestCubit();
      final query = QueryClient().getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data';
        },
      );

      final initialState = cubit.state.status;
      final statesAfterClose = <QueryState<String>>[];

      cubit.subscribeToQuery<String>(
        query,
        (state) {
          if (cubit.isClosed) {
            statesAfterClose.add(state);
          } else {
            cubit.emit(state);
          }
        },
      );

      final fetchFuture = query.fetch();
      await cubit.close();
      await fetchFuture;
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.status, initialState);
      expect(cubit.state.data, isNull);
    });

    test('handles subscription to same query multiple times', () async {
      final cubit = _TestCubit();
      final query = QueryClient().getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async => 'data',
      );

      cubit.subscribeToQuery<String>(
        query,
        (state) => cubit.emit(state),
      );
      cubit.subscribeToQuery<String>(
        query,
        (state) => cubit.emit(state),
      );

      expect(cubit.subscriptionCount, 2);
      await cubit.close();
    });
  });
}

/// Test cubit that uses FasqSubscriptionMixin for testing.
class _TestCubit extends Cubit<QueryState<String>> with FasqSubscriptionMixin {
  _TestCubit() : super(QueryState<String>.idle());
}
