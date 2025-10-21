import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:fasq/fasq.dart';

void main() {
  group('Query Combiners', () {
    setUp(() {
      QueryClient.resetForTesting();
    });

    group('CombinedQueryState2', () {
      test('provides correct state helpers', () {
        final state1 = QueryState<String>.success('data1');
        final state2 = QueryState<int>.success(42);
        final combined = CombinedQueryState2(state1, state2);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isFalse);
        expect(combined.isAllSuccess, isTrue);
        expect(combined.hasAnyError, isFalse);
        expect(combined.isAllData, isTrue);
      });

      test('handles mixed states correctly', () {
        final state1 = QueryState<String>.loading();
        final state2 = QueryState<int>.success(42);
        final combined = CombinedQueryState2(state1, state2);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isTrue);
        expect(combined.isAllSuccess, isFalse);
        expect(combined.hasAnyError, isFalse);
        expect(combined.isAllData, isFalse);
      });

      test('handles errors correctly', () {
        final state1 = QueryState<String>.success('data1');
        final state2 = QueryState<int>.error(Exception('Test error'));
        final combined = CombinedQueryState2(state1, state2);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isFalse);
        expect(combined.isAllSuccess, isFalse);
        expect(combined.hasAnyError, isTrue);
        expect(combined.isAllData, isFalse);
      });

      test('equality works correctly', () {
        final state1 = QueryState<String>.success('data1');
        final state2 = QueryState<int>.success(42);
        final combined1 = CombinedQueryState2(state1, state2);
        final combined2 = CombinedQueryState2(state1, state2);
        final combined3 = CombinedQueryState2(state2, state1);

        expect(combined1, equals(combined2));
        expect(combined1, isNot(equals(combined3)));
      });
    });

    group('CombinedQueryState3', () {
      test('provides correct state helpers', () {
        final state1 = QueryState<String>.success('data1');
        final state2 = QueryState<int>.success(42);
        final state3 = QueryState<bool>.success(true);
        final combined = CombinedQueryState3(state1, state2, state3);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isFalse);
        expect(combined.isAllSuccess, isTrue);
        expect(combined.hasAnyError, isFalse);
        expect(combined.isAllData, isTrue);
      });

      test('handles mixed states correctly', () {
        final state1 = QueryState<String>.loading();
        final state2 = QueryState<int>.success(42);
        final state3 = QueryState<bool>.error(Exception('Test error'));
        final combined = CombinedQueryState3(state1, state2, state3);

        expect(combined.isAllLoading, isFalse);
        expect(combined.isAnyLoading, isTrue);
        expect(combined.isAllSuccess, isFalse);
        expect(combined.hasAnyError, isTrue);
        expect(combined.isAllData, isFalse);
      });

      test('equality works correctly', () {
        final state1 = QueryState<String>.success('data1');
        final state2 = QueryState<int>.success(42);
        final state3 = QueryState<bool>.success(true);
        final combined1 = CombinedQueryState3(state1, state2, state3);
        final combined2 = CombinedQueryState3(state1, state2, state3);
        final combined3 = CombinedQueryState3(state2, state1, state3);

        expect(combined1, equals(combined2));
        expect(combined1, isNot(equals(combined3)));
      });
    });

    group('combineQueries2', () {
      testWidgets('combines two providers correctly', (tester) async {
        Future<String> fetchData1() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data1';
        }

        Future<int> fetchData2() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 42;
        }

        final provider1 = queryProvider('query1', fetchData1);
        final provider2 = queryProvider('query2', fetchData2);
        final combinedProvider = combineQueries2(provider1, provider2);

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
                      Text('data1: ${combined.state1.data ?? 'null'}'),
                      Text('data2: ${combined.state2.data ?? 'null'}'),
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

        // Still loading (second query)
        expect(find.text('loading: true'), findsOneWidget);
        expect(find.text('data1: data1'), findsOneWidget);

        // Wait for all to complete
        await tester.pumpAndSettle();

        // All successful
        expect(find.text('loading: false'), findsOneWidget);
        expect(find.text('success: true'), findsOneWidget);
        expect(find.text('data1: data1'), findsOneWidget);
        expect(find.text('data2: 42'), findsOneWidget);
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

        final provider1 = queryProvider('success', fetchSuccess);
        final provider2 = queryProvider('error', fetchError);
        final combinedProvider = combineQueries2(provider1, provider2);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  final combined = ref.watch(combinedProvider);

                  return Column(
                    children: [
                      Text('hasError: ${combined.hasAnyError}'),
                      Text('success: ${combined.state1.hasData}'),
                      Text('error: ${combined.state2.hasError}'),
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
    });

    group('combineQueries3', () {
      testWidgets('combines three providers correctly', (tester) async {
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

        final provider1 = queryProvider('query1', fetchData1);
        final provider2 = queryProvider('query2', fetchData2);
        final provider3 = queryProvider('query3', fetchData3);
        final combinedProvider =
            combineQueries3(provider1, provider2, provider3);

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
                      Text('data1: ${combined.state1.data ?? 'null'}'),
                      Text('data2: ${combined.state2.data ?? 'null'}'),
                      Text('data3: ${combined.state3.data ?? 'null'}'),
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
    });

    group('Provider lifecycle', () {
      testWidgets('properly disposes when not watched', (tester) async {
        Future<String> fetchData() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data';
        }

        final provider1 = queryProvider('query1', fetchData);
        final provider2 = queryProvider('query2', fetchData);
        final combinedProvider = combineQueries2(provider1, provider2);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  final combined = ref.watch(combinedProvider);
                  return Text(combined.state1.data ?? 'loading');
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
        expect(client.hasQuery('query1'), isFalse);
        expect(client.hasQuery('query2'), isFalse);
      });
    });
  });
}
