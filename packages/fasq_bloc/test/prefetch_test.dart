import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrefetchQueryCubit', () {
    test('prefetches correctly', () async {
      final cubit = PrefetchQueryCubit();
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        return 'test-data';
      }

      await cubit.prefetch('test-key', fetchData);
      
      expect(fetchCount, equals(1));
      
      cubit.close();
    });

    test('prefetchAll works with multiple configs', () async {
      final cubit = PrefetchQueryCubit();
      int fetchCount1 = 0;
      int fetchCount2 = 0;

      Future<String> fetchData1() async {
        fetchCount1++;
        return 'test-data-1';
      }

      Future<String> fetchData2() async {
        fetchCount2++;
        return 'test-data-2';
      }

      await cubit.prefetchAll([
        PrefetchConfig(key: 'test-key-1', queryFn: fetchData1),
        PrefetchConfig(key: 'test-key-2', queryFn: fetchData2),
      ]);
      
      expect(fetchCount1, equals(1));
      expect(fetchCount2, equals(1));
      
      cubit.close();
    });
  });

  group('PrefetchBuilder', () {
    testWidgets('prefetches on mount', (tester) async {
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        return 'test-data';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: PrefetchBuilder(
            configs: [
              PrefetchConfig(key: 'test-key', queryFn: fetchData),
            ],
            child: const SizedBox(),
          ),
        ),
      );

      await tester.pump();

      expect(fetchCount, equals(1));
    });

    testWidgets('multiple configs work in parallel', (tester) async {
      int fetchCount1 = 0;
      int fetchCount2 = 0;

      Future<String> fetchData1() async {
        fetchCount1++;
        return 'test-data-1';
      }

      Future<String> fetchData2() async {
        fetchCount2++;
        return 'test-data-2';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: PrefetchBuilder(
            configs: [
              PrefetchConfig(key: 'test-key-1', queryFn: fetchData1),
              PrefetchConfig(key: 'test-key-2', queryFn: fetchData2),
            ],
            child: const SizedBox(),
          ),
        ),
      );

      await tester.pump();

      expect(fetchCount1, equals(1));
      expect(fetchCount2, equals(1));
    });
  });
}
