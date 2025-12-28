import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await QueryClient.resetForTesting();
  });

  test('enabled=false keeps query idle and prevents fetch', () async {
    final client = QueryClient();
    int calls = 0;
    final query = client.getQuery<String>(
      'enabled:false'.toQueryKey(),
      queryFn: () async {
        calls++;
        return 'data';
      },
      options: QueryOptions(enabled: false),
    );

    query.addListener();
    await query.fetch();

    expect(query.state.isIdle, true);
    expect(calls, 0);
  });

  test('toggling enabled to true allows fetch', () async {
    final client = QueryClient();
    int calls = 0;
    var enabled = false;
    final queryKey = 'toggle'.toQueryKey();
    final q = client.getQuery<String>(
      queryKey,
      queryFn: () async {
        calls++;
        return 'ok';
      },
      options: QueryOptions(enabled: enabled),
    );
    q.addListener();

    expect(q.state.isIdle, true);

    // simulate enabling by creating a new query with same key and enabled true
    enabled = true;
    final q2 = client.getQuery<String>(
      queryKey,
      queryFn: () async {
        calls++;
        return 'ok';
      },
      options: QueryOptions(enabled: enabled),
    );
    q2.addListener();
    await q2.fetch();

    expect(q2.state.isSuccess, true);
    expect(calls > 0, true);
  });
}
