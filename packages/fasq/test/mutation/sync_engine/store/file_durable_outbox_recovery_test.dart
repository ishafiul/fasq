import 'dart:convert';
import 'dart:io';

import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/file_durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_envelope.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/security/outbox_encryption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fasq-outbox-recovery-');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test('recovers a dead owner marker before its lease expires', () async {
    final writer = _newStore(directory, _FakeOutboxEncryption());
    await writer.open();
    await writer.transact(
      (current) => current.copyWith(active: [_operation('retained')]),
    );
    await writer.close();

    await File(p.join(directory.path, 'outbox.lock')).writeAsString('crashed');
    final recovery = _newStore(
      directory,
      _FakeOutboxEncryption(),
    );

    final snapshot = await recovery.open();

    expect(snapshot.active.single.operationId.value, 'retained');
    await recovery.close();
    expect(File(p.join(directory.path, 'outbox.json')).existsSync(), isTrue);
  });

  test(
    'does not restore stale backup after primary decryption failure',
    () async {
      final encryption = _FakeOutboxEncryption();
      final writer = _newStore(directory, encryption);
      await writer.open();
      await writer.transact(
        (current) => current.copyWith(active: [_operation('operation-1')]),
      );
      await writer.transact(
        (current) => current.copyWith(
          active: [
            _operation('operation-1'),
            _operation('operation-2'),
          ],
        ),
      );
      await writer.close();

      final primaryBeforeFailure = await _readPrimary(directory);
      final recovery = _newStore(directory, _DecryptFailureEncryption());

      await expectLater(
        recovery.open,
        throwsA(isA<OutboxEncryptionException>()),
      );

      expect(await _readPrimary(directory), primaryBeforeFailure);
      expect(recovery.isOpen, isFalse);
    },
  );

  test(
    'does not restore stale backup after migration callback failure',
    () async {
      final encryption = _FakeOutboxEncryption();
      final writer = _newStore(directory, encryption);
      await writer.open();
      await writer.transact(
        (current) => current.copyWith(active: [_operation('stale-operation')]),
      );
      await writer.close();

      final currentPrimary = await _readPrimary(directory);
      await File(_backupPath(directory)).writeAsBytes(currentPrimary);
      final oldPrimary = _withSchemaVersion(currentPrimary, 0);
      await File(_primaryPath(directory)).writeAsBytes(oldPrimary);

      final recovery = _newStore(
        directory,
        _FakeOutboxEncryption(),
        migrations: [
          OutboxMigration(
            fromVersion: 0,
            toVersion: 1,
            migrate: (_) => throw StateError('injected migration callback'),
          ),
        ],
      );

      await expectLater(
        recovery.open,
        throwsA(isA<OutboxMigrationRequiredException>()),
      );

      expect(await _readPrimary(directory), oldPrimary);
      expect(recovery.isOpen, isFalse);
    },
  );

  test('rejects migration that overshoots the current schema', () async {
    final writer = _newStore(directory, _FakeOutboxEncryption());
    await writer.open();
    await writer.close();

    final oldPrimary = _withSchemaVersion(await _readPrimary(directory), 0);
    await File(_primaryPath(directory)).writeAsBytes(oldPrimary);

    final recovery = _newStore(
      directory,
      _FakeOutboxEncryption(),
      migrations: [
        OutboxMigration(
          fromVersion: 0,
          toVersion: currentOutboxSchemaVersion + 1,
          migrate: (payload) => payload,
        ),
      ],
    );

    await expectLater(
      recovery.open,
      throwsA(isA<OutboxMigrationRequiredException>()),
    );
    expect(await _readPrimary(directory), oldPrimary);
  });

  test(
    'does not restore stale backup after migrated payload validation fails',
    () async {
      final writer = _newStore(directory, _FakeOutboxEncryption());
      await writer.open();
      await writer.transact(
        (current) => current.copyWith(active: [_operation('stale-operation')]),
      );
      await writer.close();

      final currentPrimary = await _readPrimary(directory);
      await File(_backupPath(directory)).writeAsBytes(currentPrimary);
      final oldPrimary = _withSchemaVersion(currentPrimary, 0);
      await File(_primaryPath(directory)).writeAsBytes(oldPrimary);

      final recovery = _newStore(
        directory,
        _FakeOutboxEncryption(),
        migrations: [
          OutboxMigration(
            fromVersion: 0,
            toVersion: 1,
            migrate: (_) => <String, Object?>{},
          ),
        ],
      );

      await expectLater(
        recovery.open,
        throwsA(isA<OutboxMigrationRequiredException>()),
      );
      expect(await _readPrimary(directory), oldPrimary);
    },
  );

  test('replaces backup through temp write and atomic renames', () async {
    final fileSystem = _RecordingFileSystem();
    final store = _newStore(
      directory,
      _FakeOutboxEncryption(),
      fileSystem: fileSystem,
    );
    await store.open();
    fileSystem.operations.clear();

    await store.transact(
      (current) => current.copyWith(active: [_operation('operation-1')]),
    );

    final renames = fileSystem.operations
        .where((operation) => operation.startsWith('rename:'))
        .toList();
    expect(renames, hasLength(2));
    expect(renames.first, contains('outbox.json.bak.tmp.'));
    expect(renames.first, endsWith('->outbox.json.bak'));
    expect(renames.last, contains('outbox.json.tmp.'));
    expect(renames.last, endsWith('->outbox.json'));
    expect(
      fileSystem.operations.where((operation) => operation.startsWith('copy:')),
      isEmpty,
    );

    await store.close();
  });

  test('backup rename failure preserves the primary', () async {
    final fileSystem = _RecordingFileSystem()..failBackupRename = true;
    final store = _newStore(
      directory,
      _FakeOutboxEncryption(),
      fileSystem: fileSystem,
    );
    await store.open();
    final primaryBeforeFailure = await _readPrimary(directory);

    await expectLater(
      store.transact(
        (current) => current.copyWith(active: [_operation('operation-1')]),
      ),
      throwsA(isA<DurableOutboxException>()),
    );

    expect(await _readPrimary(directory), primaryBeforeFailure);
    expect(store.snapshot.active, isEmpty);
    expect(
      fileSystem.operations.where((operation) => operation.startsWith('copy:')),
      isEmpty,
    );

    await store.close();
  });

  test('propagates an injected primary read failure', () async {
    final writer = _newStore(directory, _FakeOutboxEncryption());
    await writer.open();
    await writer.transact(
      (current) => current.copyWith(active: [_operation('operation-1')]),
    );
    await writer.close();
    final primaryBeforeFailure = await _readPrimary(directory);

    final recovery = _newStore(
      directory,
      _FakeOutboxEncryption(),
      fileSystem: _RecordingFileSystem()..failPrimaryRead = true,
    );

    await expectLater(
      recovery.open,
      throwsA(
        isA<DurableOutboxException>().having(
          (error) => error.code,
          'code',
          DurableOutboxErrorCode.storage,
        ),
      ),
    );
    expect(await _readPrimary(directory), primaryBeforeFailure);
  });
}

FileDurableOutbox _newStore(
  Directory directory,
  OutboxEncryption encryption, {
  OutboxFileSystem fileSystem = const IoOutboxFileSystem(),
  List<OutboxMigration> migrations = const <OutboxMigration>[],
  Duration lockLease = const Duration(hours: 24),
}) {
  return FileDurableOutbox(
    directoryPath: directory.path,
    encryption: encryption,
    fileSystem: fileSystem,
    migrations: migrations,
    lockLease: lockLease,
  );
}

String _primaryPath(Directory directory) =>
    p.join(directory.path, 'outbox.json');

String _backupPath(Directory directory) =>
    p.join(directory.path, 'outbox.json.bak');

Future<List<int>> _readPrimary(Directory directory) =>
    File(_primaryPath(directory)).readAsBytes();

List<int> _withSchemaVersion(List<int> bytes, int schemaVersion) {
  final envelope = OutboxEnvelope.fromJson(
    _stringMap(jsonDecode(utf8.decode(bytes))),
  );
  return utf8.encode(
    jsonEncode(
      OutboxEnvelope(
        schemaVersion: schemaVersion,
        generation: envelope.generation,
        checksum: envelope.checksum,
        payload: envelope.payload,
      ).toJson(),
    ),
  );
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw StateError('Expected JSON object');
  }
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
}

MutationOperation _operation(String id) {
  return MutationOperation(
    operationId: OperationId(id),
    mutationKey: MutationKey(namespace: 'test', name: 'createTodo'),
    variables: const <String, Object?>{'title': 'todo'},
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

class _DecryptFailureEncryption extends _FakeOutboxEncryption {
  @override
  Future<List<int>> decrypt(List<int> ciphertext) async {
    throw const OutboxEncryptionException();
  }
}

class _RecordingFileSystem implements OutboxFileSystem {
  final _delegate = const IoOutboxFileSystem();
  final operations = <String>[];
  bool failBackupRename = false;
  bool failPrimaryRead = false;

  @override
  Future<void> ensureDirectory(String path) => _delegate.ensureDirectory(path);

  @override
  Future<bool> exists(String path) => _delegate.exists(path);

  @override
  Future<List<int>> read(String path) async {
    operations.add('read:${p.basename(path)}');
    if (failPrimaryRead && p.basename(path) == 'outbox.json') {
      throw const DurableOutboxException(
        DurableOutboxErrorCode.storage,
        'Injected primary read failure',
      );
    }
    return _delegate.read(path);
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    operations.add('write:${p.basename(path)}');
    await _delegate.write(path, bytes);
  }

  @override
  Future<void> copy(String source, String destination) async {
    operations.add('copy:${p.basename(source)}->${p.basename(destination)}');
    await _delegate.copy(source, destination);
  }

  @override
  Future<void> rename(String source, String destination) async {
    final operation =
        'rename:${p.basename(source)}->${p.basename(destination)}';
    operations.add(operation);
    if (failBackupRename && p.basename(destination) == 'outbox.json.bak') {
      throw const DurableOutboxException(
        DurableOutboxErrorCode.storage,
        'Injected backup rename failure',
      );
    }
    await _delegate.rename(source, destination);
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
