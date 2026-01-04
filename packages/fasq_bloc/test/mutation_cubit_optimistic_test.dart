import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MutationCubit Optimistic Updates', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    test('onMutate updates cache immediately with optimistic data', () async {
      final queryClient = QueryClient();
      final cubit = _TodoMutationCubit(queryClient);

      queryClient.setQueryData<List<Todo>>(
        'todos'.toQueryKey(),
        [Todo(id: '1', title: 'Existing', completed: false)],
      );

      final optimisticTodo =
          Todo(id: 'temp', title: 'New Todo', completed: false);

      cubit.mutate(
        'New Todo',
        onMutate: () {
          final previousTodos =
              queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
          queryClient.setQueryData<List<Todo>>(
            'todos'.toQueryKey(),
            [...?previousTodos, optimisticTodo],
          );
          return previousTodos;
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final cachedData =
          queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
      expect(cachedData, isNotNull);
      expect(cachedData!.length, 2);
      expect(cachedData.last.title, 'New Todo');

      await cubit.close();
      await queryClient.dispose();
    });

    test('onError rolls back cache to previous state on mutation failure',
        () async {
      final queryClient = QueryClient();
      final cubit = _FailingTodoMutationCubit(queryClient);

      final originalTodos = [
        Todo(id: '1', title: 'Existing', completed: false),
      ];
      queryClient.setQueryData<List<Todo>>(
        'todos'.toQueryKey(),
        originalTodos,
      );

      final optimisticTodo =
          Todo(id: 'temp', title: 'New Todo', completed: false);

      cubit.mutate(
        'New Todo',
        onMutate: () {
          final previousTodos =
              queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
          queryClient.setQueryData<List<Todo>>(
            'todos'.toQueryKey(),
            [...?previousTodos, optimisticTodo],
          );
          return previousTodos;
        },
        onError: (error, context) {
          if (context != null) {
            queryClient.setQueryData<List<Todo>>(
              'todos'.toQueryKey(),
              context as List<Todo>,
            );
          }
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      final cachedData =
          queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
      expect(cachedData, isNotNull);
      expect(cachedData!.length, 1);
      expect(cachedData.first.title, 'Existing');

      await cubit.close();
      await queryClient.dispose();
    });

    test('onSettled invalidates query after successful mutation', () async {
      final queryClient = QueryClient();
      final cubit = _TodoMutationCubit(queryClient);

      bool invalidated = false;

      cubit.mutate(
        'New Todo',
        onSettled: () {
          queryClient.invalidateQuery('todos'.toQueryKey());
          invalidated = true;
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(invalidated, true);

      await cubit.close();
      await queryClient.dispose();
    });

    test('onSettled invalidates query after failed mutation', () async {
      final queryClient = QueryClient();
      final cubit = _FailingTodoMutationCubit(queryClient);

      bool invalidated = false;

      cubit.mutate(
        'New Todo',
        onError: (_, __) {},
        onSettled: () {
          queryClient.invalidateQuery('todos'.toQueryKey());
          invalidated = true;
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(invalidated, true);

      await cubit.close();
      await queryClient.dispose();
    });

    test(
        'optimistic update flow: onMutate -> mutation -> onSuccess -> onSettled',
        () async {
      final queryClient = QueryClient();
      final cubit = _TodoMutationCubit(queryClient);

      final executionOrder = <String>[];
      final optimisticTodo =
          Todo(id: 'temp', title: 'New Todo', completed: false);

      queryClient.setQueryData<List<Todo>>(
        'todos'.toQueryKey(),
        [Todo(id: '1', title: 'Existing', completed: false)],
      );

      cubit.mutate(
        'New Todo',
        onMutate: () {
          executionOrder.add('onMutate');
          final previousTodos =
              queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
          queryClient.setQueryData<List<Todo>>(
            'todos'.toQueryKey(),
            [...?previousTodos, optimisticTodo],
          );
          return previousTodos;
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
      await queryClient.dispose();
    });

    test(
        'optimistic update rollback flow: onMutate -> mutation -> onError -> onSettled',
        () async {
      final queryClient = QueryClient();
      final cubit = _FailingTodoMutationCubit(queryClient);

      final executionOrder = <String>[];
      final optimisticTodo =
          Todo(id: 'temp', title: 'New Todo', completed: false);

      queryClient.setQueryData<List<Todo>>(
        'todos'.toQueryKey(),
        [Todo(id: '1', title: 'Existing', completed: false)],
      );

      cubit.mutate(
        'New Todo',
        onMutate: () {
          executionOrder.add('onMutate');
          final previousTodos =
              queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
          queryClient.setQueryData<List<Todo>>(
            'todos'.toQueryKey(),
            [...?previousTodos, optimisticTodo],
          );
          return previousTodos;
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
      await queryClient.dispose();
    });

    test('context from onMutate is correctly passed to onError for rollback',
        () async {
      final queryClient = QueryClient();
      final cubit = _FailingTodoMutationCubit(queryClient);

      final originalTodos = [
        Todo(id: '1', title: 'Todo 1', completed: false),
        Todo(id: '2', title: 'Todo 2', completed: true),
      ];
      queryClient.setQueryData<List<Todo>>(
        'todos'.toQueryKey(),
        originalTodos,
      );

      List<Todo>? rollbackData;

      cubit.mutate(
        'New Todo',
        onMutate: () {
          final previousTodos =
              queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
          queryClient.setQueryData<List<Todo>>(
            'todos'.toQueryKey(),
            [
              ...?previousTodos,
              Todo(id: 'temp', title: 'New Todo', completed: false)
            ],
          );
          return previousTodos;
        },
        onError: (error, context) {
          rollbackData = context as List<Todo>?;
          if (rollbackData != null) {
            queryClient.setQueryData<List<Todo>>(
              'todos'.toQueryKey(),
              rollbackData!,
            );
          }
        },
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(rollbackData, isNotNull);
      expect(rollbackData!.length, 2);
      expect(rollbackData![0].title, 'Todo 1');
      expect(rollbackData![1].title, 'Todo 2');

      final cachedData =
          queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
      expect(cachedData, rollbackData);

      await cubit.close();
      await queryClient.dispose();
    });

    test('optimistic update works with multiple queries', () async {
      final queryClient = QueryClient();
      final cubit = _TodoMutationCubit(queryClient);

      queryClient.setQueryData<List<Todo>>(
        'todos'.toQueryKey(),
        [Todo(id: '1', title: 'Todo 1', completed: false)],
      );
      queryClient.setQueryData<int>(
        'todos-count'.toQueryKey(),
        1,
      );

      cubit.mutate(
        'New Todo',
        onMutate: () {
          final previousTodos =
              queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
          final previousCount =
              queryClient.getQueryData<int>('todos-count'.toQueryKey());

          queryClient.setQueryData<List<Todo>>(
            'todos'.toQueryKey(),
            [
              ...?previousTodos,
              Todo(id: 'temp', title: 'New Todo', completed: false)
            ],
          );
          queryClient.setQueryData<int>(
            'todos-count'.toQueryKey(),
            (previousCount ?? 0) + 1,
          );

          return {'todos': previousTodos, 'count': previousCount};
        },
        onError: (error, context) {
          if (context != null && context is Map) {
            final todos = context['todos'] as List<Todo>?;
            final count = context['count'] as int?;
            if (todos != null) {
              queryClient.setQueryData<List<Todo>>(
                'todos'.toQueryKey(),
                todos,
              );
            }
            if (count != null) {
              queryClient.setQueryData<int>(
                'todos-count'.toQueryKey(),
                count,
              );
            }
          }
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final todos = queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
      final count = queryClient.getQueryData<int>('todos-count'.toQueryKey());

      expect(todos?.length, 2);
      expect(count, 2);

      await cubit.close();
      await queryClient.dispose();
    });

    test('optimistic update handles null previous data', () async {
      final queryClient = QueryClient();
      final cubit = _TodoMutationCubit(queryClient);

      cubit.mutate(
        'New Todo',
        onMutate: () {
          final previousTodos =
              queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
          queryClient.setQueryData<List<Todo>>(
            'todos'.toQueryKey(),
            [
              ...?previousTodos,
              Todo(id: 'temp', title: 'New Todo', completed: false)
            ],
          );
          return previousTodos;
        },
        onError: (error, context) {
          if (context != null) {
            queryClient.setQueryData<List<Todo>>(
              'todos'.toQueryKey(),
              context as List<Todo>,
            );
          }
        },
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final cachedData =
          queryClient.getQueryData<List<Todo>>('todos'.toQueryKey());
      expect(cachedData, isNotNull);
      expect(cachedData!.length, 1);

      await cubit.close();
      await queryClient.dispose();
    });
  });
}

class Todo {
  final String id;
  final String title;
  final bool completed;

  Todo({
    required this.id,
    required this.title,
    required this.completed,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        other.id == id &&
        other.title == title &&
        other.completed == completed;
  }

  @override
  int get hashCode => Object.hash(id, title, completed);
}

class _TodoMutationCubit extends MutationCubit<Todo, String> {
  final QueryClient _client;

  _TodoMutationCubit(this._client);

  @override
  QueryClient? get client => _client;

  @override
  Future<Todo> Function(String variables) get mutationFn => (title) async {
        await Future.delayed(const Duration(milliseconds: 5));
        return Todo(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            completed: false);
      };
}

class _FailingTodoMutationCubit extends MutationCubit<Todo, String> {
  final QueryClient _client;

  _FailingTodoMutationCubit(this._client);

  @override
  QueryClient? get client => _client;

  @override
  Future<Todo> Function(String variables) get mutationFn => (title) async {
        await Future.delayed(const Duration(milliseconds: 5));
        throw Exception('Mutation failed');
      };
}
