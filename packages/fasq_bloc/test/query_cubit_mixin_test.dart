import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:fasq_bloc/src/mixins/fasq_subscription_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryCubit with FasqSubscriptionMixin', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    test('QueryCubit uses FasqSubscriptionMixin', () {
      final cubit = _TestQueryCubit();

      expect(cubit, isA<FasqSubscriptionMixin>());
      expect(cubit.subscriptionCount, 1);
      expect(cubit.state.isIdle, true);

      cubit.close();
    });

    test('QueryCubit subscribes to query stream via mixin', () async {
      final cubit = _TestQueryCubit();

      expect(cubit.subscriptionCount, 1);

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.hasData, true);
      expect(cubit.state.data, 'test data');

      await cubit.close();
    });

    test('QueryCubit receives state updates from query stream', () async {
      final cubit = _TestQueryCubit();
      final states = <QueryState<String>>[];

      cubit.stream.listen((state) {
        states.add(state);
      });

      cubit.refetch();
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

    test('QueryCubit close() cancels subscription via mixin', () async {
      final cubit = _TestQueryCubit();

      expect(cubit.subscriptionCount, 1);

      await cubit.close();

      expect(cubit.subscriptionCount, 0);
    });

    test('QueryCubit does not emit state after close()', () async {
      final cubit = _TestQueryCubit();
      final initialState = cubit.state.status;
      final statesAfterClose = <QueryState<String>>[];

      cubit.stream.listen((state) {
        if (cubit.isClosed) {
          statesAfterClose.add(state);
        }
      });

      cubit.refetch();
      await cubit.close();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.status, initialState);
      expect(statesAfterClose, isEmpty);
    });

    test('QueryCubit respects enabled=false option', () async {
      int calls = 0;
      final cubit = _DisabledQueryCubit(() => calls++);

      expect(cubit.state.isIdle, true);
      expect(cubit.subscriptionCount, 1);
      expect(calls, 0);

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(calls, 0);
      expect(cubit.state.isIdle, true);

      await cubit.close();
    });

    test('QueryCubit handles query lifecycle methods', () async {
      final cubit = _TestQueryCubit();

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.hasData, true);

      cubit.invalidate();

      await Future.delayed(const Duration(milliseconds: 10));

      await cubit.close();
    });

    test('QueryCubit emits initial query state correctly', () async {
      final cubit = _TestQueryCubit();

      expect(cubit.state.status, QueryStatus.idle);

      await cubit.close();
    });

    test('QueryCubit handles query state transitions', () async {
      final cubit = _TestQueryCubit();
      final stateTransitions = <QueryStatus>[];

      cubit.stream.listen((state) {
        stateTransitions.add(state.status);
      });

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(stateTransitions, contains(QueryStatus.loading));
      expect(stateTransitions, contains(QueryStatus.success));

      await cubit.close();
    });

    test('QueryCubit handles query errors correctly', () async {
      final cubit = _ErrorQueryCubit();

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.hasError, true);
      expect(cubit.state.error, isA<Exception>());

      await cubit.close();
    });

    test('QueryCubit subscription is managed by mixin', () async {
      final cubit = _TestQueryCubit();

      expect(cubit.subscriptionCount, 1);

      await cubit.close();

      expect(cubit.subscriptionCount, 0);
    });

    test('QueryCubit can use custom QueryClient', () async {
      final customClient = QueryClient();
      final cubit = _CustomClientQueryCubit(customClient);

      expect(cubit.subscriptionCount, 1);

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.hasData, true);

      await cubit.close();
      await customClient.dispose();
    });
  });
}

class _TestQueryCubit extends QueryCubit<String> {
  _TestQueryCubit();

  @override
  QueryKey get queryKey => 'test-query'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
        await Future.delayed(const Duration(milliseconds: 5));
        return 'test data';
      };
}

class _DisabledQueryCubit extends QueryCubit<String> {
  final void Function() onQueryCall;

  _DisabledQueryCubit(this.onQueryCall);

  @override
  QueryKey get queryKey => 'disabled-query'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
        onQueryCall();
        return 'data';
      };

  @override
  QueryOptions? get options => QueryOptions(enabled: false);
}

class _ErrorQueryCubit extends QueryCubit<String> {
  _ErrorQueryCubit();

  @override
  QueryKey get queryKey => 'error-query'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
        await Future.delayed(const Duration(milliseconds: 5));
        throw Exception('Test error');
      };
}

class _CustomClientQueryCubit extends QueryCubit<String> {
  final QueryClient _client;

  _CustomClientQueryCubit(this._client);

  @override
  QueryKey get queryKey => 'custom-client-query'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
        await Future.delayed(const Duration(milliseconds: 5));
        return 'custom data';
      };

  @override
  QueryClient? get client => _client;
}

