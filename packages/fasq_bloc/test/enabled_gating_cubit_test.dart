import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => QueryClient.resetForTesting());

  test('QueryCubit respects enabled=false (stays idle)', () async {
    int calls = 0;
    final cubit = _TestQueryCubit(() => calls++);

    expect(cubit.state.isIdle, true);
    expect(calls, 0);
    await cubit.close();
  });
}

class _TestQueryCubit extends QueryCubit<String> {
  final void Function() onQueryCall;

  _TestQueryCubit(this.onQueryCall);

  @override
  QueryKey get queryKey => 'bloc:enabled'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
        onQueryCall();
        return 'x';
      };

  @override
  QueryOptions? get options => QueryOptions(enabled: false);
}
