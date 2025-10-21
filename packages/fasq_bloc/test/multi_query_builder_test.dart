import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:fasq/fasq.dart';

void main() {
  group('MultiQueryBuilder', () {
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
        MaterialApp(
          home: MultiQueryBuilder(
            configs: [
              MultiQueryConfig(key: 'query1', queryFn: fetchData1),
              MultiQueryConfig(key: 'query2', queryFn: fetchData2),
              MultiQueryConfig(key: 'query3', queryFn: fetchData3),
            ],
            builder: (context, state) {
              return Column(
                children: state.states
                    .map((s) => Text(s.data?.toString() ?? 'loading'))
                    .toList(),
              );
            },
          ),
        ),
      );

      // Wait for all queries to complete
      await tester.pumpAndSettle();

      // Verify all queries executed
      expect(results, contains('data1'));
      expect(results, contains('data2'));
      expect(results, contains('data3'));

      // Verify final states
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('data2'), findsOneWidget);
      expect(find.text('data3'), findsOneWidget);
    });

    testWidgets('provides correct state helpers', (tester) async {
      Future<String> fetchData1() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'data1';
      }

      Future<String> fetchData2() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return 'data2';
      }

      bool allLoading = false;
      bool anyLoading = false;
      bool allSuccess = false;
      bool hasError = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MultiQueryBuilder(
            configs: [
              MultiQueryConfig(key: 'query1', queryFn: fetchData1),
              MultiQueryConfig(key: 'query2', queryFn: fetchData2),
            ],
            builder: (context, state) {
              allLoading = state.isAllLoading;
              anyLoading = state.isAnyLoading;
              allSuccess = state.isAllSuccess;
              hasError = state.hasAnyError;

              return Text('${state.states.length} queries');
            },
          ),
        ),
      );

      // Initially all should be loading
      expect(allLoading, isTrue);
      expect(anyLoading, isTrue);
      expect(allSuccess, isFalse);
      expect(hasError, isFalse);

      // Wait for first query to complete
      await tester.pump(const Duration(milliseconds: 150));

      // Now only one should be loading
      expect(allLoading, isFalse);
      expect(anyLoading, isTrue);
      expect(allSuccess, isFalse);
      expect(hasError, isFalse);

      // Wait for all to complete
      await tester.pumpAndSettle();

      // All should be successful
      expect(allLoading, isFalse);
      expect(anyLoading, isFalse);
      expect(allSuccess, isTrue);
      expect(hasError, isFalse);
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
        MaterialApp(
          home: MultiQueryBuilder(
            configs: [
              MultiQueryConfig(key: 'success', queryFn: fetchSuccess),
              MultiQueryConfig(key: 'error', queryFn: fetchError),
            ],
            builder: (context, state) {
              return Column(
                children: [
                  Text(state.getState<String>(0).hasError
                      ? 'error'
                      : state.getState<String>(0).data?.toString() ??
                          'loading'),
                  Text(state.getState<String>(1).hasError
                      ? 'error'
                      : state.getState<String>(1).data?.toString() ??
                          'loading'),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // First query should succeed, second should fail
      expect(find.text('success'), findsOneWidget);
      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('properly cleans up on dispose', (tester) async {
      Future<String> fetchData(String key) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'data';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: MultiQueryBuilder(
            configs: [
              MultiQueryConfig(
                  key: 'query1', queryFn: () => fetchData('query1')),
              MultiQueryConfig(
                  key: 'query2', queryFn: () => fetchData('query2')),
            ],
            builder: (context, state) {
              return Column(
                children: state.states
                    .map((s) => Text(s.data?.toString() ?? 'loading'))
                    .toList(),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Wait a bit to ensure cleanup happens
      await tester.pump(const Duration(milliseconds: 200));

      // Verify queries are cleaned up (no memory leaks)
      final client = QueryClient();
      expect(client.hasQuery('query1'), isFalse);
      expect(client.hasQuery('query2'), isFalse);
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
        MaterialApp(
          home: MultiQueryBuilder(
            configs: [
              MultiQueryConfig(key: 'query1', queryFn: fetchData1),
              MultiQueryConfig(key: 'query2', queryFn: fetchData2),
            ],
            builder: (context, state) {
              updateCount++;

              return Column(
                children: state.states
                    .map((s) => Text(s.data?.toString() ?? 'loading'))
                    .toList(),
              );
            },
          ),
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

    testWidgets('getState returns correct typed state', (tester) async {
      Future<List<String>> fetchList() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return ['item1', 'item2'];
      }

      Future<Map<String, int>> fetchMap() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return {'count': 42};
      }

      await tester.pumpWidget(
        MaterialApp(
          home: MultiQueryBuilder(
            configs: [
              MultiQueryConfig(key: 'list', queryFn: fetchList),
              MultiQueryConfig(key: 'map', queryFn: fetchMap),
            ],
            builder: (context, state) {
              final listState = state.getState<List<String>>(0);
              final mapState = state.getState<Map<String, int>>(1);

              return Column(
                children: [
                  Text(listState.hasData
                      ? listState.data!.length.toString()
                      : 'loading'),
                  Text(mapState.hasData
                      ? mapState.data!['count'].toString()
                      : 'loading'),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify typed access works correctly
      expect(find.text('2'), findsOneWidget); // list length
      expect(find.text('42'), findsOneWidget); // map count
    });
  });
}
