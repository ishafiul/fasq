import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async => await QueryClient.resetForTesting());

  test('queryProvider respects enabled=false (stays idle)', () async {
    int calls = 0;
    final provider = queryProvider<String>(
      'rp:enabled'.toQueryKey(),
      () async {
        calls++;
        return 'ok';
      },
      options: QueryOptions(enabled: false),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // With enabled: false, the query should not auto-fetch
    // It should be in loading state initially
    final state = container.read(provider);
    expect(state.isLoading, true);
    expect(calls, 0);

    // Wait to ensure no fetch happens
    await Future.delayed(const Duration(milliseconds: 100));

    // Should still be loading (idle) with no calls made
    final stateAfter = container.read(provider);
    expect(stateAfter.isLoading, true);
    expect(calls, 0);
  });
}
