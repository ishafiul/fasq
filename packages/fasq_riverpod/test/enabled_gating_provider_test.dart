import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => QueryClient.resetForTesting());

  test('queryProvider respects enabled=false (stays idle)', () async {
    int calls = 0;
    final provider = queryProvider<String>(
      'rp:enabled',
      () async {
        calls++;
        return 'ok';
      },
      options: const QueryOptions(enabled: false),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(provider);
    expect(state.isIdle, true);
    expect(calls, 0);
  });
}
