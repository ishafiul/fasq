import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fasq_hooks/fasq_hooks.dart';

void main() {
  group('useQueries', () {
    setUp(() {
      QueryClient.resetForTesting();
    });

    testWidgets('executes all queries independently', (tester) async {
      final results = <String>[];

      Future<String> fetchData1() async {
        await Future.delayed(const Duration(milliseconds: 100));
        results.add('data1');
        return 'data1';
      }

      Future<String> fetchData2() async {
        await Future.delayed(const Duration(milliseconds: 50));
        results.add('data2');
        return 'data2';
      }

      Future<String> fetchData3() async {
        await Future.delayed(const Duration(milliseconds: 75));
        results.add('data3');
        return 'data3';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useQueries([
              QueryConfig('query1'.toQueryKey(), fetchData1),
              QueryConfig('query2'.toQueryKey(), fetchData2),
              QueryConfig('query3'.toQueryKey(), fetchData3),
            ]);

            return Column(
              children: queries
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      // Wait for all queries to complete
      await tester.pumpAndSettle();

      // Verify all queries executed
      expect(results, contains('data1'));
      expect(results, contains('data2'));
      expect(results, contains('data3'));

      // Verify final states
      // Note: In real usage, we'd access the hook state differently
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('data2'), findsOneWidget);
      expect(find.text('data3'), findsOneWidget);
    });

    testWidgets('handles config changes correctly', (tester) async {
      bool useSecondConfig = false;

      Future<String> fetchData1() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data1';
      }

      Future<String> fetchData2() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data2';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final configs = useSecondConfig
                ? [
                    QueryConfig('query1'.toQueryKey(), fetchData1),
                    QueryConfig('query2'.toQueryKey(), fetchData2)
                  ]
                : [QueryConfig('query1'.toQueryKey(), fetchData1)];

            final queries = useQueries(configs);

            return Column(
              children: queries
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Change config
      useSecondConfig = true;
      await tester.pump();
      await tester.pumpAndSettle();

      // Should have 2 queries now
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('data2'), findsOneWidget);
    });

    testWidgets('handles errors independently', (tester) async {
      Future<String> fetchSuccess() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'success';
      }

      Future<String> fetchError() async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw Exception('Test error');
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useQueries([
              QueryConfig('success'.toQueryKey(), fetchSuccess),
              QueryConfig('error'.toQueryKey(), fetchError),
            ]);

            return Column(
              children: [
                Text(queries[0].hasError
                    ? 'error'
                    : queries[0].data?.toString() ?? 'loading'),
                Text(queries[1].hasError
                    ? 'error'
                    : queries[1].data?.toString() ?? 'loading'),
              ],
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // First query should succeed, second should fail
      expect(find.text('success'), findsOneWidget);
      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('properly cleans up on unmount', (tester) async {
      Future<String> fetchData(String key) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'data';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useQueries([
              QueryConfig('query1'.toQueryKey(), () => fetchData('query1')),
              QueryConfig('query2'.toQueryKey(), () => fetchData('query2')),
            ]);

            return Column(
              children: queries
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Unmount widget
      await tester.pumpWidget(const SizedBox());

      // Wait a bit to ensure cleanup happens
      await tester.pump(const Duration(milliseconds: 200));

      // Verify queries are cleaned up (no memory leaks)
      final client = QueryClient();
      expect(client.hasQuery('query1'.toQueryKey()), isFalse);
      expect(client.hasQuery('query2'.toQueryKey()), isFalse);
    });

    testWidgets('updates states independently', (tester) async {
      int updateCount = 0;

      Future<String> fetchData1() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'data1';
      }

      Future<String> fetchData2() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return 'data2';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useQueries([
              QueryConfig('query1'.toQueryKey(), fetchData1),
              QueryConfig('query2'.toQueryKey(), fetchData2),
            ]);

            updateCount++;

            return Column(
              children: queries
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      // Should rebuild as queries complete independently
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('loading'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('data2'), findsOneWidget);

      // Should have rebuilt multiple times as states updated
      expect(updateCount, greaterThan(1));
    });
  });

  group('useNamedQueries', () {
    setUp(() {
      QueryClient.resetForTesting();
    });

    testWidgets('executes all named queries independently', (tester) async {
      final results = <String>[];

      Future<String> fetchUsers() async {
        await Future.delayed(const Duration(milliseconds: 100));
        results.add('users');
        return 'users';
      }

      Future<String> fetchPosts() async {
        await Future.delayed(const Duration(milliseconds: 50));
        results.add('posts');
        return 'posts';
      }

      Future<String> fetchComments() async {
        await Future.delayed(const Duration(milliseconds: 75));
        results.add('comments');
        return 'comments';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useNamedQueries([
              NamedQueryConfig(
                  name: 'users', queryKey: 'users'.toQueryKey(), queryFn: fetchUsers),
              NamedQueryConfig(
                  name: 'posts', queryKey: 'posts'.toQueryKey(), queryFn: fetchPosts),
              NamedQueryConfig(
                  name: 'comments', queryKey: 'comments'.toQueryKey(), queryFn: fetchComments),
            ]);

            return Column(
              children: [
                Text(queries['users']?.data?.toString() ?? 'loading'),
                Text(queries['posts']?.data?.toString() ?? 'loading'),
                Text(queries['comments']?.data?.toString() ?? 'loading'),
              ],
            );
          },
        ),
      );

      // Wait for all queries to complete
      await tester.pumpAndSettle();

      // Verify all queries executed
      expect(results, contains('users'));
      expect(results, contains('posts'));
      expect(results, contains('comments'));

      // Verify final states
      expect(find.text('users'), findsOneWidget);
      expect(find.text('posts'), findsOneWidget);
      expect(find.text('comments'), findsOneWidget);
    });

    testWidgets('handles config changes correctly', (tester) async {
      bool useSecondConfig = false;

      Future<String> fetchUsers() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'users';
      }

      Future<String> fetchPosts() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'posts';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final configs = useSecondConfig
                ? [
                    NamedQueryConfig(
                        name: 'users', queryKey: 'users'.toQueryKey(), queryFn: fetchUsers),
                    NamedQueryConfig(
                        name: 'posts', queryKey: 'posts'.toQueryKey(), queryFn: fetchPosts),
                  ]
                : [
                    NamedQueryConfig(
                        name: 'users', queryKey: 'users'.toQueryKey(), queryFn: fetchUsers),
                  ];

            final queries = useNamedQueries(configs);

            return Column(
              children: queries.entries
                  .map((entry) => Text(
                      '${entry.key}: ${entry.value.data?.toString() ?? 'loading'}'))
                  .toList(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Change config
      useSecondConfig = true;
      await tester.pump();
      await tester.pumpAndSettle();

      // Should have 2 queries now
      expect(find.text('users: users'), findsOneWidget);
      expect(find.text('posts: posts'), findsOneWidget);
    });

    testWidgets('handles errors independently', (tester) async {
      Future<String> fetchSuccess() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'success';
      }

      Future<String> fetchError() async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw Exception('Test error');
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useNamedQueries([
              NamedQueryConfig(
                  name: 'success', queryKey: 'success'.toQueryKey(), queryFn: fetchSuccess),
              NamedQueryConfig(
                  name: 'error', queryKey: 'error'.toQueryKey(), queryFn: fetchError),
            ]);

            return Column(
              children: [
                Text(queries['success']?.hasError == true
                    ? 'error'
                    : queries['success']?.data?.toString() ?? 'loading'),
                Text(queries['error']?.hasError == true
                    ? 'error'
                    : queries['error']?.data?.toString() ?? 'loading'),
              ],
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // First query should succeed, second should fail
      expect(find.text('success'), findsOneWidget);
      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('properly cleans up on unmount', (tester) async {
      Future<String> fetchData(String key) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'data';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useNamedQueries([
              NamedQueryConfig(
                  name: 'query1',
                  queryKey: 'query1'.toQueryKey(),
                  queryFn: () => fetchData('query1')),
              NamedQueryConfig(
                  name: 'query2',
                  queryKey: 'query2'.toQueryKey(),
                  queryFn: () => fetchData('query2')),
            ]);

            return Column(
              children: queries.values
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Unmount widget
      await tester.pumpWidget(const SizedBox());

      // Wait a bit to ensure cleanup happens
      await tester.pump(const Duration(milliseconds: 200));

      // Verify queries are cleaned up (no memory leaks)
      final client = QueryClient();
      expect(client.hasQuery('query1'.toQueryKey()), isFalse);
      expect(client.hasQuery('query2'.toQueryKey()), isFalse);
    });

    testWidgets('updates states independently', (tester) async {
      int updateCount = 0;

      Future<String> fetchUsers() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'users';
      }

      Future<String> fetchPosts() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return 'posts';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useNamedQueries([
              NamedQueryConfig(
                  name: 'users', queryKey: 'users'.toQueryKey(), queryFn: fetchUsers),
              NamedQueryConfig(
                  name: 'posts', queryKey: 'posts'.toQueryKey(), queryFn: fetchPosts),
            ]);

            updateCount++;

            return Column(
              children: queries.values
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      // Should rebuild as queries complete independently
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('users'), findsOneWidget);
      expect(find.text('loading'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('users'), findsOneWidget);
      expect(find.text('posts'), findsOneWidget);

      // Should have rebuilt multiple times as states updated
      expect(updateCount, greaterThan(1));
    });

    testWidgets('named access works correctly', (tester) async {
      Future<List<String>> fetchUsers() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return ['user1', 'user2'];
      }

      Future<Map<String, int>> fetchStats() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return {'count': 42};
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useNamedQueries([
              NamedQueryConfig(
                  name: 'users', queryKey: 'users'.toQueryKey(), queryFn: fetchUsers),
              NamedQueryConfig(
                  name: 'stats', queryKey: 'stats'.toQueryKey(), queryFn: fetchStats),
            ]);

            final usersState = queries['users']!;
            final statsState = queries['stats']!;

            return Column(
              children: [
                Text(usersState.hasData
                    ? usersState.data!.length.toString()
                    : 'loading'),
                Text(statsState.hasData
                    ? statsState.data!['count'].toString()
                    : 'loading'),
              ],
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Verify named access works correctly
      expect(find.text('2'), findsOneWidget); // users length
      expect(find.text('42'), findsOneWidget); // stats count
    });
  });
}
