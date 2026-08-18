import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MutationKey', () {
    test('keeps a stable versioned key and round trips', () {
      final key = MutationKey(namespace: 'todos', name: 'create', version: 2);

      final restored = MutationKey.fromJson(key.toJson());

      expect(restored, equals(key));
      expect(restored.key, equals('todos:create:v2'));
    });

    test('rejects invalid key segments and versions', () {
      expect(
        () => MutationKey(namespace: '', name: 'create'),
        throwsArgumentError,
      );
      expect(
        () => MutationKey(namespace: 'todos', name: 'create', version: 0),
        throwsArgumentError,
      );
      expect(
        () => MutationKey(namespace: 'todos:private', name: 'create'),
        throwsArgumentError,
      );
    });
  });

  group('AuthScope and operation contracts', () {
    test('round trips scope and operation descriptors', () {
      final operation = MutationOperation(
        operationId: OperationId('operation-1'),
        mutationKey: MutationKey(namespace: 'todos', name: 'create'),
        variables: const <String, Object?>{'title': 'Offline'},
        createdAt: DateTime.utc(2026, 8, 19),
        idempotencyKey: IdempotencyKey('idempotency-1'),
        lineageId: LineageId('lineage-1'),
        authPolicy: AuthPolicy.required,
        authScope: AuthScope(
          principalId: 'user-1',
          tenantId: 'tenant-1',
          authRealm: 'primary',
        ),
        dependencies: <MutationDependency>[
          MutationDependency(
            parentOperationId: OperationId('parent-1'),
            parentResultPath: 'id',
            childVariablePath: 'todoId',
          ),
        ],
        projections: <MutationProjectionDescriptor>[
          MutationProjectionDescriptor(
            id: 'todo-detail',
            queryKeys: const <String>['todo:temporary-1'],
          ),
        ],
        state: MutationOperationState.pending,
      );

      final restored = MutationOperation.fromJson(operation.toJson());

      expect(restored.operationId, equals(operation.operationId));
      expect(restored.mutationKey, equals(operation.mutationKey));
      expect(restored.variables, equals(operation.variables));
      expect(restored.authScope, equals(operation.authScope));
      expect(restored.dependencies.single.parentOperationId.value, 'parent-1');
      expect(restored.projections.single.queryKeys, <String>[
        'todo:temporary-1',
      ]);
      expect(restored.state, MutationOperationState.pending);
    });

    test('does not silently accept an unknown operation state', () {
      expect(
        () => parseMutationOperationState('futureState'),
        throwsA(isA<UnknownMutationStateException>()),
      );
    });

    test('requires exact scope for authenticated operations', () {
      expect(
        () => MutationOperation(
          operationId: OperationId('operation-1'),
          mutationKey: MutationKey(namespace: 'todos', name: 'create'),
          variables: const <String, Object?>{},
          createdAt: DateTime.utc(2026, 8, 19),
          idempotencyKey: IdempotencyKey('idempotency-1'),
          lineageId: LineageId('lineage-1'),
          authPolicy: AuthPolicy.required,
          state: MutationOperationState.pending,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-JSON operation variables', () {
      final operation = MutationOperation(
        operationId: OperationId('operation-1'),
        mutationKey: MutationKey(namespace: 'todos', name: 'create'),
        variables: const <String, Object?>{},
        createdAt: DateTime.utc(2026, 8, 19),
        idempotencyKey: IdempotencyKey('idempotency-1'),
        lineageId: LineageId('lineage-1'),
        authPolicy: AuthPolicy.none,
        state: MutationOperationState.pending,
      );
      final invalidPayload = operation.toJson()
        ..['variables'] = DateTime.utc(2026, 8, 19);

      expect(
        () => MutationOperation.fromJson(invalidPayload),
        throwsA(isA<InvalidMutationPayloadException>()),
      );
    });

    test('rejects invalid operation timestamps as contract errors', () {
      final operation = MutationOperation(
        operationId: OperationId('operation-1'),
        mutationKey: MutationKey(namespace: 'todos', name: 'create'),
        variables: const <String, Object?>{},
        createdAt: DateTime.utc(2026, 8, 19),
        idempotencyKey: IdempotencyKey('idempotency-1'),
        lineageId: LineageId('lineage-1'),
        authPolicy: AuthPolicy.none,
        state: MutationOperationState.pending,
      );
      final invalidPayload = operation.toJson()..['createdAt'] = 'not-a-date';

      expect(
        () => MutationOperation.fromJson(invalidPayload),
        throwsA(isA<InvalidMutationPayloadException>()),
      );
    });
  });

  group('MutationCodecRegistry', () {
    final key = MutationKey(namespace: 'todos', name: 'create');

    test('encodes and decodes typed variables', () {
      final registry = MutationCodecRegistry()
        ..register<Map<String, Object?>>(
          key,
          JsonMutationCodec<Map<String, Object?>>(
            encoder: (value) => value,
            decoder: (payload) {
              if (payload is! Map<Object?, Object?>) {
                throw const InvalidMutationPayloadException('Expected object');
              }
              return Map<String, Object?>.fromEntries(
                payload.entries.map((entry) {
                  if (entry.key is! String) {
                    throw const InvalidMutationPayloadException(
                      'Expected string keys',
                    );
                  }
                  final entryKey = entry.key;
                  if (entryKey is! String) {
                    throw const InvalidMutationPayloadException(
                      'Expected string keys',
                    );
                  }
                  return MapEntry(entryKey, entry.value);
                }),
              );
            },
          ),
        );

      final payload = registry.encode(key, <String, Object?>{'title': 'Todo'});

      expect(payload, <String, Object?>{'title': 'Todo'});
      expect(registry.decode(key, payload), <String, Object?>{'title': 'Todo'});
    });

    test('rejects unsupported payloads and unknown keys', () {
      final registry = MutationCodecRegistry()
        ..register<Object?>(
          key,
          JsonMutationCodec<Object?>(
            encoder: (value) => value,
            decoder: (payload) => payload,
          ),
        );

      expect(
        () => registry.encode(key, DateTime.utc(2026)),
        throwsA(isA<InvalidMutationPayloadException>()),
      );
      expect(
        () => registry.decode(
          MutationKey(namespace: 'todos', name: 'missing'),
          <String, Object?>{},
        ),
        throwsA(isA<UnknownMutationKeyException>()),
      );
      expect(
        () => registry.decode(
          MutationKey(namespace: 'todos', name: 'create', version: 2),
          'Todo',
        ),
        throwsA(isA<UnknownMutationKeyException>()),
      );
      expect(
        () => MutationKey.fromJson(const <String, Object?>{
          'namespace': 'todos',
          'name': 'create',
          'version': 1.5,
        }),
        throwsA(isA<InvalidMutationPayloadException>()),
      );
    });

    test('rejects duplicate registrations', () {
      final registry = MutationCodecRegistry();
      final codec = JsonMutationCodec<String>(
        encoder: (value) => value,
        decoder: (payload) {
          if (payload is! String) {
            throw const InvalidMutationPayloadException('Expected string');
          }
          return payload;
        },
      );

      registry.register(key, codec);

      expect(
        () => registry.register(key, codec),
        throwsA(isA<DuplicateMutationRegistrationException>()),
      );
    });
  });

  test('registers an executor without persisting the closure', () async {
    final registry = MutationRegistrationRegistry();
    final key = MutationKey(namespace: 'todos', name: 'create');
    registry.register<String, String>(
      key: key,
      codec: JsonMutationCodec<String>(
        encoder: (value) => value,
        decoder: (payload) {
          if (payload is! String) {
            throw const InvalidMutationPayloadException('Expected string');
          }
          return payload;
        },
      ),
      authPolicy: AuthPolicy.required,
      mutationFn: (value) async => 'created:$value',
    );

    expect(registry.authPolicyFor(key), AuthPolicy.required);
    expect(
      registry.readinessFor(key),
      MutationRegistrationReadiness.ready,
    );
    expect(
      registry.readinessFor(
        MutationKey(namespace: 'todos', name: 'missing'),
      ),
      MutationRegistrationReadiness.missing,
    );
    expect(await registry.execute(key, 'todo'), 'created:todo');
    expect(registry.registeredKeys, contains(key));
  });
}
