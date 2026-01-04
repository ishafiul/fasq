import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MutationCubit Lifecycle Hooks', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    test('onMutate is called before mutation starts', () async {
      final cubit = _TestMutationCubit();
      final callOrder = <String>[];

      cubit.mutate(
        'test',
        onMutate: () {
          callOrder.add('onMutate');
          return 'context';
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(callOrder.first, 'onMutate');
      await cubit.close();
    });

    test('onSuccess is called after successful mutation', () async {
      final cubit = _TestMutationCubit();
      final callOrder = <String>[];
      String? successData;

      cubit.mutate(
        'test',
        onMutate: () {
          callOrder.add('onMutate');
          return null;
        },
        onSuccess: (data) {
          callOrder.add('onSuccess');
          successData = data;
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(callOrder, contains('onMutate'));
      expect(callOrder, contains('onSuccess'));
      expect(callOrder.indexOf('onMutate'),
          lessThan(callOrder.indexOf('onSuccess')));
      expect(successData, 'test result');
      await cubit.close();
    });

    test('onError is called after failed mutation', () async {
      final cubit = _ErrorMutationCubit();
      final callOrder = <String>[];
      Object? errorReceived;
      dynamic contextReceived;

      cubit.mutate(
        'test',
        onMutate: () {
          callOrder.add('onMutate');
          return 'rollback context';
        },
        onError: (error, context) {
          callOrder.add('onError');
          errorReceived = error;
          contextReceived = context;
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(callOrder, contains('onMutate'));
      expect(callOrder, contains('onError'));
      expect(callOrder.indexOf('onMutate'),
          lessThan(callOrder.indexOf('onError')));
      expect(errorReceived, isA<Exception>());
      expect(contextReceived, 'rollback context');
      await cubit.close();
    });

    test('onSettled is always called after mutation completes (success)',
        () async {
      final cubit = _TestMutationCubit();
      final callOrder = <String>[];

      cubit.mutate(
        'test',
        onMutate: () {
          callOrder.add('onMutate');
          return null;
        },
        onSuccess: (_) {
          callOrder.add('onSuccess');
        },
        onSettled: () {
          callOrder.add('onSettled');
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(callOrder.last, 'onSettled');
      expect(callOrder, contains('onMutate'));
      expect(callOrder, contains('onSuccess'));
      await cubit.close();
    });

    test('onSettled is always called after mutation completes (error)',
        () async {
      final cubit = _ErrorMutationCubit();
      final callOrder = <String>[];

      cubit.mutate(
        'test',
        onMutate: () {
          callOrder.add('onMutate');
          return null;
        },
        onError: (_, __) {
          callOrder.add('onError');
        },
        onSettled: () {
          callOrder.add('onSettled');
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(callOrder.last, 'onSettled');
      expect(callOrder, contains('onMutate'));
      expect(callOrder, contains('onError'));
      await cubit.close();
    });

    test('context from onMutate is passed to onError for rollback', () async {
      final cubit = _ErrorMutationCubit();
      const rollbackData = {'previous': 'value'};
      dynamic receivedContext;

      cubit.mutate(
        'test',
        onMutate: () {
          return rollbackData;
        },
        onError: (error, context) {
          receivedContext = context;
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(receivedContext, rollbackData);
      await cubit.close();
    });

    test('mutation works without any lifecycle hooks', () async {
      final cubit = _TestMutationCubit();

      cubit.mutate('test');

      await Future.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.isSuccess, true);
      expect(cubit.state.data, 'test result');
      await cubit.close();
    });

    test('mutation works with only onMutate and onSettled', () async {
      final cubit = _TestMutationCubit();
      final callOrder = <String>[];

      cubit.mutate(
        'test',
        onMutate: () {
          callOrder.add('onMutate');
          return null;
        },
        onSettled: () {
          callOrder.add('onSettled');
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(callOrder, contains('onMutate'));
      expect(callOrder, contains('onSettled'));
      expect(cubit.state.isSuccess, true);
      await cubit.close();
    });

    test('onMutate can return null context', () async {
      final cubit = _ErrorMutationCubit();
      dynamic receivedContext;

      cubit.mutate(
        'test',
        onMutate: () => null,
        onError: (error, context) {
          receivedContext = context;
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(receivedContext, isNull);
      await cubit.close();
    });

    test('callbacks handle async operations correctly', () async {
      final cubit = _TestMutationCubit();
      final callOrder = <String>[];

      cubit.mutate(
        'test',
        onMutate: () async {
          await Future.delayed(const Duration(milliseconds: 5));
          callOrder.add('onMutate');
          return null;
        },
        onSuccess: (_) async {
          await Future.delayed(const Duration(milliseconds: 5));
          callOrder.add('onSuccess');
        },
        onSettled: () async {
          await Future.delayed(const Duration(milliseconds: 5));
          callOrder.add('onSettled');
        },
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect(callOrder, ['onMutate', 'onSuccess', 'onSettled']);
      await cubit.close();
    });

    test('onError receives correct error and context when mutation fails',
        () async {
      final cubit = _ErrorMutationCubit();
      const testContext = {'key': 'value'};
      Object? errorReceived;
      dynamic contextReceived;

      cubit.mutate(
        'test',
        onMutate: () => testContext,
        onError: (error, context) {
          errorReceived = error;
          contextReceived = context;
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(errorReceived, isA<Exception>());
      expect(contextReceived, testContext);
      await cubit.close();
    });

    test('lifecycle hooks are not called if cubit is closed', () async {
      final cubit = _TestMutationCubit();
      bool onMutateCalled = false;
      bool onSuccessCalled = false;
      bool onSettledCalled = false;

      await cubit.close();

      cubit.mutate(
        'test',
        onMutate: () {
          onMutateCalled = true;
          return null;
        },
        onSuccess: (_) {
          onSuccessCalled = true;
        },
        onSettled: () {
          onSettledCalled = true;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(onMutateCalled, false);
      expect(onSuccessCalled, false);
      expect(onSettledCalled, false);
    });

    test(
        'correct execution order: onMutate -> mutation -> onSuccess -> onSettled',
        () async {
      final cubit = _TestMutationCubit();
      final executionOrder = <String>[];

      cubit.mutate(
        'test',
        onMutate: () {
          executionOrder.add('onMutate');
          return null;
        },
        onSuccess: (_) {
          executionOrder.add('onSuccess');
        },
        onSettled: () {
          executionOrder.add('onSettled');
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(executionOrder[0], 'onMutate');
      expect(executionOrder[1], 'onSuccess');
      expect(executionOrder[2], 'onSettled');
      await cubit.close();
    });

    test(
        'correct execution order: onMutate -> mutation -> onError -> onSettled',
        () async {
      final cubit = _ErrorMutationCubit();
      final executionOrder = <String>[];

      cubit.mutate(
        'test',
        onMutate: () {
          executionOrder.add('onMutate');
          return null;
        },
        onError: (_, __) {
          executionOrder.add('onError');
        },
        onSettled: () {
          executionOrder.add('onSettled');
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(executionOrder[0], 'onMutate');
      expect(executionOrder[1], 'onError');
      expect(executionOrder[2], 'onSettled');
      await cubit.close();
    });
  });
}

class _TestMutationCubit extends MutationCubit<String, String> {
  _TestMutationCubit();

  @override
  Future<String> Function(String variables) get mutationFn =>
      (variables) async {
        await Future.delayed(const Duration(milliseconds: 5));
        return 'test result';
      };
}

class _ErrorMutationCubit extends MutationCubit<String, String> {
  _ErrorMutationCubit();

  @override
  Future<String> Function(String variables) get mutationFn =>
      (variables) async {
        await Future.delayed(const Duration(milliseconds: 5));
        throw Exception('Test error');
      };
}
