import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MutationOptions durable queue contract', () {
    test('preserves const online-only configuration', () {
      const options = MutationOptions<String, String>();

      expect(options.queueWhenOffline, isFalse);
      expect(options.durableQueue, isNull);
      expect(options.mutationKey, isNull);
      expect(options.codec, isNull);
      expect(options.authPolicy, AuthPolicy.none);
    });

    test('requires durable configuration when queueing is enabled', () {
      expect(
        () => MutationOptions<String, String>(queueWhenOffline: true),
        throwsA(isA<AssertionError>()),
      );
    });

    test('exposes stable key and typed codec through public options', () {
      final key = MutationKey(namespace: 'todos', name: 'create', version: 2);
      final codec = JsonMutationCodec<Map<String, Object?>>(
        encoder: (variables) => variables,
        decoder: (payload) => Map<String, Object?>.from(payload! as Map),
      );
      final options = MutationOptions<String, Map<String, Object?>>(
        queueWhenOffline: true,
        durableQueue: DurableMutationQueueOptions(
          queue: DurableMutationQueue(store: _MemoryOutboxStore()),
          mutationKey: key,
          codec: codec,
          authPolicy: AuthPolicy.required,
          authScope: AuthScope(
            principalId: 'user-1',
            tenantId: 'tenant-1',
            authRealm: 'primary',
          ),
        ),
      );

      expect(options.mutationKey, same(key));
      expect(options.mutationKey!.key, 'todos:create:v2');
      expect(options.codec, same(codec));
      expect(options.authPolicy, AuthPolicy.required);
      expect(options.durableQueue!.authScope!.principalId, 'user-1');
      expect(options.durableQueue, isNotNull);
      expect(options.validateDurableConfiguration, returnsNormally);

      final payload = options.codec!.encode(<String, Object?>{'title': 'Buy'});
      expect(options.codec!.decode(payload), <String, Object?>{'title': 'Buy'});
    });

    test('rejects non-JSON variables through the typed codec', () {
      final options = MutationOptions<String, DateTime>(
        queueWhenOffline: true,
        durableQueue: DurableMutationQueueOptions(
          queue: DurableMutationQueue(store: _MemoryOutboxStore()),
          mutationKey: MutationKey(namespace: 'todos', name: 'create'),
          codec: JsonMutationCodec<DateTime>(
            encoder: (variables) => variables,
            decoder: (_) => DateTime.utc(2026),
          ),
        ),
      );

      expect(
        () => options.codec!.encode(DateTime.utc(2026)),
        throwsA(isA<InvalidMutationPayloadException>()),
      );
    });
  });
}

class _MemoryOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;

  @override
  Future<OutboxSnapshot> open() async => _snapshot;

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  int get generation => _generation;

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) async {
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }

  @override
  Future<void> close() async {}
}
