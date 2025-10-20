import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => QueryClient.resetForTesting());

  test('QueryCubit respects enabled=false (stays idle)', () async {
    int calls = 0;
    final cubit = QueryCubit<String>(
      key: 'bloc:enabled',
      queryFn: () async {
        calls++;
        return 'x';
      },
      options: const QueryOptions(enabled: false),
    );

    expect(cubit.state.isIdle, true);
    expect(calls, 0);
    await cubit.close();
  });
}
