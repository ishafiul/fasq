import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    QueryClient.resetForTesting();
  });

  test('enabled=false keeps query idle and prevents fetch', () async {
    final client = QueryClient();
    int calls = 0;
    final query = client.getQuery<String>(
      'enabled:false',
      () async {
        calls++;
        return 'data';
      },
      options: const QueryOptions(enabled: false),
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
    final q = client.getQuery<String>(
      'toggle',
      () async {
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
      'toggle',
      () async {
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
