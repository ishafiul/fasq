import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => QueryCache.gcInterval = Duration.zero);
  tearDown(() async => QueryClient.resetForTesting());

  testWidgets('prefetch callback returns a future', (tester) async {
    Future<void> Function(
      QueryKey,
      Future<String> Function(), {
      QueryOptions? options,
    })?
    prefetch;
    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            prefetch = usePrefetchQuery<String>();
            return const SizedBox();
          },
        ),
      ),
    );

    await prefetch!('prefetched'.toQueryKey(), () async => 'value');
    expect(
      QueryClient().getQueryData<String>('prefetched'.toQueryKey()),
      'value',
    );
  });

  testWidgets('prefetches all mount configurations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            usePrefetchOnMount([
              PrefetchConfig<String>(
                queryKey: 'a'.toQueryKey(),
                queryFn: () async => 'A',
              ),
              PrefetchConfig<String>(
                queryKey: 'b'.toQueryKey(),
                queryFn: () async => 'B',
              ),
            ]);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(QueryClient().getQueryData<String>('a'.toQueryKey()), 'A');
    expect(QueryClient().getQueryData<String>('b'.toQueryKey()), 'B');
  });
}
