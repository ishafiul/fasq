import 'dart:convert';
import 'dart:io';

import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/file_durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_envelope.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/security/outbox_encryption.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fasq-outbox-test-');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test('commits one logical snapshot after encrypted durable write', () async {
    final encryption = _FakeOutboxEncryption();
    final store = _newStore(directory, encryption);

    expect((await store.open()).active, isEmpty);
    final operation = _operation('operation-1', variables: {'title': 'secret'});
    await store.transact(
      (current) => current.copyWith(active: [operation]),
    );

    expect(store.generation, 1);
    expect(store.snapshot.active.single.operationId.value, 'operation-1');
    final bytes = await File('${directory.path}/outbox.json').readAsBytes();
    expect(utf8.decode(bytes), isNot(contains('secret')));
    await store.close();
  });

  test(
    'switches to encrypted append journal for sustained mutations',
    () async {
      final store = _newStore(directory, _FakeOutboxEncryption());
      await store.open();

      for (var index = 1; index <= 10; index++) {
        await store.transact(
          (current) => current.copyWith(
            active: [
              ...current.active,
              _operation('operation-$index'),
            ],
          ),
        );
      }
      await store.close();

      expect(File('${directory.path}/outbox.json.log').existsSync(), isTrue);
      final recovered = _newStore(directory, _FakeOutboxEncryption());
      await recovered.open();
      expect(recovered.generation, 10);
      expect(recovered.snapshot.active, hasLength(10));
      expect(
        recovered.snapshot.active.last.operationId.value,
        'operation-10',
      );
      await recovered.close();
    },
  );

  test('restores the last-known-good backup without clearing work', () async {
    final encryption = _FakeOutboxEncryption();
    final first = _newStore(directory, encryption);
    await first.open();
    await first.transact(
      (current) => current.copyWith(
        active: [_operation('operation-1')],
      ),
    );
    await first.transact(
      (current) => current.copyWith(
        active: [
          _operation('operation-1'),
          _operation('operation-2'),
        ],
      ),
    );
    await first.close();

    await File('${directory.path}/outbox.json').writeAsString('corrupt');
    final recovered = _newStore(directory, _FakeOutboxEncryption());
    await recovered.open();

    expect(recovered.generation, 1);
    expect(recovered.snapshot.active.single.operationId.value, 'operation-1');
    expect(
      directory.listSync().whereType<File>().any(
        (file) => file.path.contains('.corrupt.'),
      ),
      isTrue,
    );
    await recovered.close();
  });

  test('rejects stale generation and capacity overflow', () async {
    final store = _newStore(
      directory,
      _FakeOutboxEncryption(),
      capacity: const OutboxCapacityPolicy(maxRecords: 1),
    );
    await store.open();
    await store.transact(
      (current) => current.copyWith(active: [_operation('operation-1')]),
    );

    expect(
      () => store.transact(
        (current) => current,
        expectedGeneration: 0,
      ),
      throwsA(isA<OutboxGenerationConflictException>()),
    );
    expect(
      () => store.transact(
        (current) => current.copyWith(
          active: [
            _operation('operation-1'),
            _operation('operation-2'),
          ],
        ),
      ),
      throwsA(isA<OutboxCapacityExceededException>()),
    );
    await store.close();
  });

  test('rejects credential-like fields before persistence', () async {
    final store = _newStore(directory, _FakeOutboxEncryption());
    await store.open();

    expect(
      () => store.transact(
        (current) => current.copyWith(
          active: [
            _operation('operation-1', variables: {'refreshToken': 'value'}),
          ],
        ),
      ),
      throwsA(isA<OutboxCredentialRejectedException>()),
    );
    expect(store.snapshot.active, isEmpty);
    await store.close();
  });

  test('fails closed when another owner holds the store', () async {
    final first = _newStore(directory, _FakeOutboxEncryption());
    await first.open();
    expect(File('${directory.path}/outbox.lock').existsSync(), isTrue);
    final second = _newStore(directory, _FakeOutboxEncryption());

    try {
      await second.open();
      fail('Expected the second owner to be rejected');
    } on OutboxOwnershipException {
      // Expected: ownership is exclusive while the first store is open.
    }
    await first.close();
  });

  test('rejects future envelope versions without resetting data', () async {
    final encryption = _FakeOutboxEncryption();
    final store = _newStore(directory, encryption);
    await store.open();
    await store.close();
    final payload = base64Encode(
      await encryption.encrypt(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'active': <Object?>[],
            'deadLetters': <Object?>[],
            'history': <Object?>[],
            'metadata': <String, Object?>{},
          }),
        ),
      ),
    );
    final envelope = OutboxEnvelope(
      schemaVersion: currentOutboxSchemaVersion + 1,
      generation: 1,
      checksum: 'not-used',
      payload: payload,
    );
    await File('${directory.path}/outbox.json').writeAsString(
      jsonEncode(envelope.toJson()),
    );

    final futureStore = _newStore(directory, _FakeOutboxEncryption());
    expect(
      futureStore.open,
      throwsA(isA<OutboxMigrationRequiredException>()),
    );
    expect(
      File('${directory.path}/outbox.json').readAsStringSync(),
      contains('schemaVersion'),
    );
  });

  test('does not acknowledge a transaction when atomic rename fails', () async {
    final first = _newStore(directory, _FakeOutboxEncryption());
    await first.open();
    await first.close();

    final store = _newStore(
      directory,
      _FakeOutboxEncryption(),
      fileSystem: const _FailingRenameFileSystem(),
    );
    await store.open();

    expect(
      () => store.transact(
        (current) => current.copyWith(active: [_operation('operation-1')]),
      ),
      throwsA(isA<DurableOutboxException>()),
    );
    expect(store.snapshot.active, isEmpty);
    await store.close();
  });
}

FileDurableOutbox _newStore(
  Directory directory,
  OutboxEncryption encryption, {
  OutboxCapacityPolicy capacity = const OutboxCapacityPolicy(),
  OutboxFileSystem fileSystem = const IoOutboxFileSystem(),
}) {
  return FileDurableOutbox(
    directoryPath: directory.path,
    encryption: encryption,
    capacity: capacity,
    fileSystem: fileSystem,
  );
}

MutationOperation _operation(
  String id, {
  Object? variables = const <String, Object?>{'title': 'todo'},
}) {
  return MutationOperation(
    operationId: OperationId(id),
    mutationKey: MutationKey(namespace: 'test', name: 'createTodo'),
    variables: variables,
    createdAt: DateTime.utc(2026),
    idempotencyKey: IdempotencyKey('idempotency-$id'),
    lineageId: LineageId('lineage-$id'),
    authPolicy: AuthPolicy.none,
    state: MutationOperationState.pending,
  );
}

class _FakeOutboxEncryption implements OutboxEncryption {
  @override
  Future<void> prepare({required bool allowCreateKey}) async {}

  @override
  Future<List<int>> encrypt(List<int> plaintext) async =>
      plaintext.map((byte) => byte ^ 0xAA).toList(growable: false);

  @override
  Future<List<int>> decrypt(List<int> ciphertext) async =>
      ciphertext.map((byte) => byte ^ 0xAA).toList(growable: false);
}

class _FailingRenameFileSystem implements OutboxFileSystem {
  const _FailingRenameFileSystem();

  static const _delegate = IoOutboxFileSystem();

  @override
  Future<void> ensureDirectory(String path) => _delegate.ensureDirectory(path);

  @override
  Future<bool> exists(String path) => _delegate.exists(path);

  @override
  Future<List<int>> read(String path) => _delegate.read(path);

  @override
  Future<void> write(String path, List<int> bytes) =>
      _delegate.write(path, bytes);

  @override
  Future<void> copy(String source, String destination) =>
      _delegate.copy(source, destination);

  @override
  Future<void> rename(String source, String destination) async {
    throw const DurableOutboxException(
      DurableOutboxErrorCode.storage,
      'Injected atomic rename failure',
    );
  }

  @override
  Future<void> delete(String path) => _delegate.delete(path);

  @override
  Future<void> acquireLock(String path) => _delegate.acquireLock(path);

  @override
  Future<void> releaseLock(String path) => _delegate.releaseLock(path);

  @override
  Future<bool> recoverStaleLock(
    String path, {
    required Duration lease,
    required DateTime now,
  }) => _delegate.recoverStaleLock(path, lease: lease, now: now);
}
