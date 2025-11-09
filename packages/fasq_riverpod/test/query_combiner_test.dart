import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fasq_riverpod/fasq_riverpod.dart';

void main() {
  group('Dynamic Query Combiners', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    group('CombinedQueriesState', () {
      test('provides correct state helpers', () {
        final state1 = QueryState<String>.success('data1');
        final state2 = QueryState<int>.success(42);
        final state3 = QueryState<bool>.success(true);
        final combined = CombinedQueriesState([state1, state2, state3]);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isFalse);
        expect(combined.isAllSuccess, isTrue);
        expect(combined.hasAnyError, isFalse);
        expect(combined.isAllData, isTrue);
        expect(combined.length, equals(3));
      });

      test('handles mixed states correctly', () {
        final state1 = QueryState<String>.loading();
        final state2 = QueryState<int>.success(42);
        final state3 = QueryState<bool>.error(Exception('Test error'));
        final combined = CombinedQueriesState([state1, state2, state3]);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isTrue);
        expect(combined.isAllSuccess, isFalse);
        expect(combined.hasAnyError, isTrue);
        expect(combined.isAllData, isFalse);
      });

      test('equality works correctly', () {
        final state1 = QueryState<String>.success('data1');
        final state2 = QueryState<int>.success(42);
        final combined1 = CombinedQueriesState([state1, state2]);
        final combined2 = CombinedQueriesState([state1, state2]);
        final combined3 = CombinedQueriesState([state2, state1]);

        expect(combined1, equals(combined2));
        expect(combined1, isNot(equals(combined3)));
      });

      test('getState returns correct typed state', () {
        final state1 = QueryState<List<String>>.success(['item1', 'item2']);
        final state2 = QueryState<Map<String, int>>.success({'count': 42});
        final combined = CombinedQueriesState([state1, state2]);

        final listState = combined.getState<List<String>>(0);
        final mapState = combined.getState<Map<String, int>>(1);

        expect(listState.data, equals(['item1', 'item2']));
        expect(mapState.data, equals({'count': 42}));
      });
    });

    group('NamedQueriesState', () {
      test('provides correct state helpers', () {
        final states = {
          'users': QueryState<String>.success('data1'),
          'posts': QueryState<int>.success(42),
          'comments': QueryState<bool>.success(true),
        };
        final combined = NamedQueriesState(states);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isFalse);
        expect(combined.isAllSuccess, isTrue);
        expect(combined.hasAnyError, isFalse);
        expect(combined.isAllData, isTrue);
        expect(combined.length, equals(3));
      });

      test('handles mixed states correctly', () {
        final states = {
          'users': QueryState<String>.loading(),
          'posts': QueryState<int>.success(42),
          'comments': QueryState<bool>.error(Exception('Test error')),
        };
        final combined = NamedQueriesState(states);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isTrue);
        expect(combined.isAllSuccess, isFalse);
        expect(combined.hasAnyError, isTrue);
        expect(combined.isAllData, isFalse);
      });

      test('named access works correctly', () {
        final states = {
          'users': QueryState<String>.success('data1'),
          'posts': QueryState<int>.success(42),
        };
        final combined = NamedQueriesState(states);

        expect(combined.getState<String>('users').data, equals('data1'));
        expect(combined.getState<int>('posts').data, equals(42));
        expect(combined.isLoading('users'), isFalse);
        expect(combined.hasError('posts'), isFalse);
      });

      test('equality works correctly', () {
        final states1 = {
          'users': QueryState<String>.success('data1'),
          'posts': QueryState<int>.success(42),
        };
        final states2 = {
          'users': QueryState<String>.success('data1'),
          'posts': QueryState<int>.success(42),
        };
        final combined1 = NamedQueriesState(states1);
        final combined2 = NamedQueriesState(states2);

        expect(combined1, equals(combined2));
      });
    });

    group('combineQueries', () {
      testWidgets('combines multiple providers correctly', (tester) async {
        Future<String> fetchData1() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data1';
        }

        Future<int> fetchData2() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 42;
        }

        Future<bool> fetchData3() async {
          await Future.delayed(const Duration(milliseconds: 150));
          return true;
        }

        final provider1 = queryProvider('query1'.toQueryKey(), fetchData1);
        final provider2 = queryProvider('query2'.toQueryKey(), fetchData2);
        final provider3 = queryProvider('query3'.toQueryKey(), fetchData3);
        final combinedProvider =
            combineQueries([provider1, provider2, provider3]);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  final combined = ref.watch(combinedProvider);

                  return Column(
                    children: [
                      Text('loading: ${combined.isAnyLoading}'),
                      Text('success: ${combined.isAllSuccess}'),
                      Text(
                          'data1: ${combined.getState<String>(0).data ?? 'null'}'),
                      Text(
                          'data2: ${combined.getState<int>(1).data ?? 'null'}'),
                      Text(
                          'data3: ${combined.getState<bool>(2).data ?? 'null'}'),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Initially loading
        expect(find.text('loading: true'), findsOneWidget);
        expect(find.text('success: false'), findsOneWidget);

        // Wait for first query to complete
        await tester.pump(const Duration(milliseconds: 75));

        // Still loading (other queries)
        expect(find.text('loading: true'), findsOneWidget);
        expect(find.text('data1: data1'), findsOneWidget);

        // Wait for second query to complete
        await tester.pump(const Duration(milliseconds: 50));

        // Still loading (third query)
        expect(find.text('loading: true'), findsOneWidget);
        expect(find.text('data2: 42'), findsOneWidget);

        // Wait for all to complete
        await tester.pumpAndSettle();

        // All successful
        expect(find.text('loading: false'), findsOneWidget);
        expect(find.text('success: true'), findsOneWidget);
        expect(find.text('data1: data1'), findsOneWidget);
        expect(find.text('data2: 42'), findsOneWidget);
        expect(find.text('data3: true'), findsOneWidget);
      });

      testWidgets('handles errors independently', (tester) async {
        Future<String> fetchSuccess() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'success';
        }

        Future<int> fetchError() async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Test error');
        }

        final provider1 = queryProvider('success'.toQueryKey(), fetchSuccess);
        final provider2 = queryProvider('error'.toQueryKey(), fetchError);
        final combinedProvider = combineQueries([provider1, provider2]);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  final combined = ref.watch(combinedProvider);

                  return Column(
                    children: [
                      Text('hasError: ${combined.hasAnyError}'),
                      Text('success: ${combined.getState<String>(0).hasData}'),
                      Text('error: ${combined.getState<int>(1).hasError}'),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should have error from second query
        expect(find.text('hasError: true'), findsOneWidget);
        expect(find.text('success: true'), findsOneWidget);
        expect(find.text('error: true'), findsOneWidget);
      });

      testWidgets('works with 5+ providers', (tester) async {
        final providers = List.generate(
            5,
            (i) => queryProvider('query$i'.toQueryKey(), () async {
                  await Future.delayed(Duration(milliseconds: 50 + i * 10));
                  return 'data$i';
                }));

        final combinedProvider = combineQueries(providers);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  final combined = ref.watch(combinedProvider);

                  return Column(
                    children: [
                      Text('length: ${combined.length}'),
                      Text('loading: ${combined.isAnyLoading}'),
                      Text('success: ${combined.isAllSuccess}'),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('length: 5'), findsOneWidget);
        expect(find.text('loading: false'), findsOneWidget);
        expect(find.text('success: true'), findsOneWidget);
      });
    });

    group('combineNamedQueries', () {
      testWidgets('combines named providers correctly', (tester) async {
        Future<String> fetchUsers() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'users';
        }

        Future<int> fetchPosts() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 42;
        }

        Future<bool> fetchComments() async {
          await Future.delayed(const Duration(milliseconds: 150));
          return true;
        }

        final usersProvider = queryProvider('users'.toQueryKey(), fetchUsers);
        final postsProvider = queryProvider('posts'.toQueryKey(), fetchPosts);
        final commentsProvider =
            queryProvider('comments'.toQueryKey(), fetchComments);
        final combinedProvider = combineNamedQueries({
          'users': usersProvider,
          'posts': postsProvider,
          'comments': commentsProvider,
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  final combined = ref.watch(combinedProvider);

                  return Column(
                    children: [
                      Text('loading: ${combined.isAnyLoading}'),
                      Text('success: ${combined.isAllSuccess}'),
                      Text(
                          'users: ${combined.getState<String>('users').data ?? 'null'}'),
                      Text(
                          'posts: ${combined.getState<int>('posts').data ?? 'null'}'),
                      Text(
                          'comments: ${combined.getState<bool>('comments').data ?? 'null'}'),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Initially loading
        expect(find.text('loading: true'), findsOneWidget);
        expect(find.text('success: false'), findsOneWidget);

        // Wait for users to complete
        await tester.pump(const Duration(milliseconds: 75));

        // Still loading (other queries)
        expect(find.text('loading: true'), findsOneWidget);
        expect(find.text('users: users'), findsOneWidget);

        // Wait for posts to complete
        await tester.pump(const Duration(milliseconds: 50));

        // Still loading (comments)
        expect(find.text('loading: true'), findsOneWidget);
        expect(find.text('posts: 42'), findsOneWidget);

        // Wait for all to complete
        await tester.pumpAndSettle();

        // All successful
        expect(find.text('loading: false'), findsOneWidget);
        expect(find.text('success: true'), findsOneWidget);
        expect(find.text('users: users'), findsOneWidget);
        expect(find.text('posts: 42'), findsOneWidget);
        expect(find.text('comments: true'), findsOneWidget);
      });

      testWidgets('named access methods work correctly', (tester) async {
        Future<String> fetchUsers() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'users';
        }

        Future<int> fetchPosts() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 42;
        }

        final usersProvider = queryProvider('users'.toQueryKey(), fetchUsers);
        final postsProvider = queryProvider('posts'.toQueryKey(), fetchPosts);
        final combinedProvider = combineNamedQueries({
          'users': usersProvider,
          'posts': postsProvider,
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  final combined = ref.watch(combinedProvider);

                  return Column(
                    children: [
                      Text('usersLoading: ${combined.isLoading('users')}'),
                      Text('postsLoading: ${combined.isLoading('posts')}'),
                      Text('usersError: ${combined.hasError('users')}'),
                      Text('postsError: ${combined.hasError('posts')}'),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Initially both loading
        expect(find.text('usersLoading: true'), findsOneWidget);
        expect(find.text('postsLoading: true'), findsOneWidget);

        // Wait for users to complete
        await tester.pump(const Duration(milliseconds: 75));

        // Users done, posts still loading
        expect(find.text('usersLoading: false'), findsOneWidget);
        expect(find.text('postsLoading: true'), findsOneWidget);

        // Wait for all to complete
        await tester.pumpAndSettle();

        // Both done
        expect(find.text('usersLoading: false'), findsOneWidget);
        expect(find.text('postsLoading: false'), findsOneWidget);
        expect(find.text('usersError: false'), findsOneWidget);
        expect(find.text('postsError: false'), findsOneWidget);
      });
    });

    group('Provider lifecycle', () {
      testWidgets('properly disposes when not watched', (tester) async {
        Future<String> fetchData() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data';
        }

        final provider1 = queryProvider('query1'.toQueryKey(), fetchData);
        final provider2 = queryProvider('query2'.toQueryKey(), fetchData);
        final combinedProvider = combineQueries([provider1, provider2]);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  final combined = ref.watch(combinedProvider);
                  return Text(combined.getState<String>(0).data ?? 'loading');
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Unmount widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        // Wait for cleanup
        await tester.pump(const Duration(milliseconds: 200));

        // Verify queries are cleaned up
        final client = QueryClient();
        expect(client.hasQuery('query1'.toQueryKey()), isFalse);
        expect(client.hasQuery('query2'.toQueryKey()), isFalse);
      });
    });
  });
}
