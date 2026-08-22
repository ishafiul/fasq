import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_envelope.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_security.dart';
import 'package:fasq/src/security/outbox_encryption.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A validated copy-on-write migration between logical store schemas.
class OutboxMigration {
  /// Creates a migration from [fromVersion] to [toVersion].
  const OutboxMigration({
    required this.fromVersion,
    required this.toVersion,
    required this.migrate,
  });

  /// Schema version accepted by [migrate].
  final int fromVersion;

  /// Schema version produced by [migrate].
  final int toVersion;

  /// Transforms only validated JSON-safe logical payloads.
  final Map<String, Object?> Function(Map<String, Object?> payload) migrate;
}

/// Capacity limits for the complete logical outbox.
class OutboxCapacityPolicy {
  /// Creates optional count and byte limits.
  const OutboxCapacityPolicy({this.maxRecords, this.maxBytes});

  /// Maximum number of active, dead-letter, and history records.
  final int? maxRecords;

  /// Maximum encoded envelope size in bytes.
  final int? maxBytes;

  /// Validates a candidate snapshot against the configured limits.
  void validate(OutboxSnapshot snapshot, int encodedBytes) {
    if (maxRecords != null && snapshot.recordCount > maxRecords!) {
      throw const OutboxCapacityExceededException();
    }
    if (maxBytes != null && encodedBytes > maxBytes!) {
      throw const OutboxCapacityExceededException();
    }
  }
}

/// Filesystem operations used by the durable backend.
abstract class OutboxFileSystem {
  /// Ensures a directory exists.
  Future<void> ensureDirectory(String path);

  /// Returns whether a path exists.
  Future<bool> exists(String path);

  /// Reads a file as bytes.
  Future<List<int>> read(String path);

  /// Writes bytes and flushes them before acknowledging.
  Future<void> write(String path, List<int> bytes);

  /// Copies a file without deleting the source.
  Future<void> copy(String source, String destination);

  /// Atomically renames a file within the same directory.
  Future<void> rename(String source, String destination);

  /// Deletes a file if it exists.
  Future<void> delete(String path);

  /// Acquires an exclusive owner marker.
  Future<void> acquireLock(String path);

  /// Releases an owner marker created by this backend.
  Future<void> releaseLock(String path);

  /// Removes a lock that has exceeded [lease] without touching store data.
  /// Implementations that cannot safely determine lock age return false.
  Future<bool> recoverStaleLock(
    String path, {
    required Duration lease,
    required DateTime now,
  }) async => false;
}

/// Default dart:io filesystem implementation.
class IoOutboxFileSystem implements OutboxFileSystem {
  /// Creates the dart:io implementation.
  const IoOutboxFileSystem();

  /// Keeps native locks alive for the lifetime of this Dart process.
  ///
  /// The marker file is durable evidence, but native ownership is what lets
  /// the operating system release a lock after a process is terminated.
  static final Map<String, RandomAccessFile> _ownedLocks =
      <String, RandomAccessFile>{};
  static final Set<String> _recoveredLocks = <String>{};

  @override
  Future<void> ensureDirectory(String path) async {
    try {
      await Directory(path).create(recursive: true);
    } on FileSystemException {
      throw const DurableOutboxException(
        DurableOutboxErrorCode.storage,
        'The durable outbox directory is unavailable',
      );
    }
  }

  @override
  Future<bool> exists(String path) =>
      Future<bool>.value(File(path).existsSync());

  @override
  Future<List<int>> read(String path) async {
    try {
      return await File(path).readAsBytes();
    } on FileSystemException {
      throw const DurableOutboxException(
        DurableOutboxErrorCode.storage,
        'The durable outbox could not be read',
      );
    }
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    try {
      await File(path).writeAsBytes(bytes, flush: true);
    } on FileSystemException {
      throw const DurableOutboxException(
        DurableOutboxErrorCode.storage,
        'The durable outbox could not be durably written',
      );
    }
  }

  @override
  Future<void> copy(String source, String destination) async {
    try {
      await File(source).copy(destination);
    } on FileSystemException {
      throw const DurableOutboxException(
        DurableOutboxErrorCode.storage,
        'The durable outbox backup could not be created',
      );
    }
  }

  @override
  Future<void> rename(String source, String destination) async {
    try {
      await File(source).rename(destination);
    } on FileSystemException {
      throw const DurableOutboxException(
        DurableOutboxErrorCode.storage,
        'The durable outbox could not be atomically replaced',
      );
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      throw const DurableOutboxException(
        DurableOutboxErrorCode.storage,
        'The durable outbox owner marker could not be removed',
      );
    }
  }

  @override
  Future<void> acquireLock(String path) {
    return Future<void>.sync(() {
      if (_recoveredLocks.remove(path)) return;
      _acquireNativeLock(path);
    });
  }

  void _acquireNativeLock(String path) {
    if (_ownedLocks.containsKey(path)) {
      throw const OutboxOwnershipException();
    }

    RandomAccessFile? lockFile;
    try {
      final openedLockFile = File(path).openSync(mode: FileMode.append);
      lockFile = openedLockFile;
      openedLockFile.lockSync();
      _ownedLocks[path] = openedLockFile;
    } on Object {
      try {
        lockFile?.closeSync();
      } on Object {
        // Preserve the ownership failure from the lock attempt.
      }
      throw const OutboxOwnershipException();
    }
  }

  @override
  Future<void> releaseLock(String path) async {
    final lockFile = _ownedLocks.remove(path);
    if (lockFile == null) return;

    try {
      await lockFile.unlock();
    } finally {
      await lockFile.close();
    }
    await delete(path);
  }

  @override
  Future<bool> recoverStaleLock(
    String path, {
    required Duration lease,
    required DateTime now,
  }) async {
    final file = File(path);
    if (!file.existsSync()) return false;

    // Native locks are released by the operating system when their process
    // exits, so an unlocked marker is reclaimable even before its lease age.
    // Keep the marker until acquireLock/releaseLock completes to avoid a
    // delete-and-recreate race with a live owner.
    try {
      await Future<void>.sync(() => _acquireNativeLock(path));
      _recoveredLocks.add(path);
      return true;
    } on OutboxOwnershipException {
      return false;
    }
  }
}

/// Default crash-safe encrypted file backend for the durable outbox.
class FileDurableOutbox implements DurableOutboxStore {
  /// Creates a file-backed durable outbox.
  FileDurableOutbox({
    required String directoryPath,
    required OutboxEncryption encryption,
    this.fileSystem = const IoOutboxFileSystem(),
    this.capacity = const OutboxCapacityPolicy(),
    this.securityPolicy = const OutboxSecurityPolicy(),
    this.migrations = const <OutboxMigration>[],
    this.lockLease = const Duration(hours: 24),
    DateTime Function()? now,
  }) : _directoryPath = directoryPath,
       _encryption = encryption,
       _now = now ?? DateTime.now;

  /// Creates a backend in the platform application support directory.
  static Future<FileDurableOutbox> inApplicationSupportDirectory({
    required OutboxEncryption encryption,
    OutboxFileSystem fileSystem = const IoOutboxFileSystem(),
    OutboxCapacityPolicy capacity = const OutboxCapacityPolicy(),
    OutboxSecurityPolicy securityPolicy = const OutboxSecurityPolicy(),
    List<OutboxMigration> migrations = const <OutboxMigration>[],
    Duration lockLease = const Duration(hours: 24),
    DateTime Function()? now,
  }) async {
    final directory = await getApplicationSupportDirectory();
    return FileDurableOutbox(
      directoryPath: p.join(directory.path, 'fasq', 'offline_outbox'),
      encryption: encryption,
      fileSystem: fileSystem,
      capacity: capacity,
      securityPolicy: securityPolicy,
      migrations: migrations,
      lockLease: lockLease,
      now: now,
    );
  }

  /// Filesystem dependency, replaceable for deterministic fault tests.
  final OutboxFileSystem fileSystem;

  /// Capacity guard for the complete logical store.
  final OutboxCapacityPolicy capacity;

  /// Credential redaction policy.
  final OutboxSecurityPolicy securityPolicy;

  /// Copy-on-write schema migrations.
  final List<OutboxMigration> migrations;

  /// Maximum owner-marker age before crash recovery may reclaim it.
  final Duration lockLease;

  final String _directoryPath;
  final OutboxEncryption _encryption;
  final DateTime Function() _now;
  final String _ownerToken =
      'owner-${DateTime.now().microsecondsSinceEpoch}-'
      '${identityHashCode(Object())}';
  late final String _storePath = p.join(_directoryPath, 'outbox.json');
  late final String _backupPath = p.join(_directoryPath, 'outbox.json.bak');
  late final String _lockPath = p.join(_directoryPath, 'outbox.lock');
  late final String _temporaryPath = p.join(
    _directoryPath,
    'outbox.json.tmp.$_ownerToken',
  );
  late final String _backupTemporaryPath = p.join(
    _directoryPath,
    'outbox.json.bak.tmp.$_ownerToken',
  );

  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;
  bool _isOpen = false;
  bool _ownsLock = false;
  Future<void> _tail = Future<void>.value();

  /// Whether this backend currently owns the store.
  bool get isOpen => _isOpen;

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  int get generation => _generation;

  @override
  Future<OutboxSnapshot> open() {
    return _serialized(() async {
      if (_isOpen) return _snapshot;
      if (_ownsLock) throw const OutboxOwnershipException();
      await fileSystem.ensureDirectory(_directoryPath);
      await fileSystem.recoverStaleLock(
        _lockPath,
        lease: lockLease,
        now: _now(),
      );
      await fileSystem.acquireLock(_lockPath);
      _ownsLock = true;
      try {
        final hasStore =
            await fileSystem.exists(_storePath) ||
            await fileSystem.exists(_backupPath);
        await _encryption.prepare(allowCreateKey: !hasStore);
        final loaded = await _load();
        if (loaded == null) {
          _snapshot = OutboxSnapshot();
          _generation = 0;
          await _write(_snapshot, generation: _generation);
        } else {
          _snapshot = loaded.snapshot;
          _generation = loaded.generation;
          if (loaded.wasMigrated) {
            await _write(_snapshot, generation: _generation + 1);
            _generation++;
          }
        }
        _isOpen = true;
        return _snapshot;
      } on Object {
        try {
          await _releaseLock();
        } on Object {
          // Preserve the original failure while retaining ownership state.
        }
        rethrow;
      }
    });
  }

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) {
    return _serialized(() async {
      if (!_isOpen) {
        throw const DurableOutboxException(
          DurableOutboxErrorCode.storage,
          'The durable outbox is not open',
        );
      }
      if (expectedGeneration != null && expectedGeneration != _generation) {
        throw const OutboxGenerationConflictException();
      }
      final next = transaction(_snapshot);
      securityPolicy.validate(next.toJson());
      final generation = _generation + 1;
      await _write(next, generation: generation);
      _snapshot = next;
      _generation = generation;
      return next;
    });
  }

  @override
  Future<void> close() {
    return _serialized(() async {
      if (!_ownsLock) {
        _isOpen = false;
        return;
      }
      await _releaseLock();
      _isOpen = false;
    });
  }

  Future<_LoadedOutbox?> _load() async {
    final hasPrimary = await fileSystem.exists(_storePath);
    final hasBackup = await fileSystem.exists(_backupPath);
    if (!hasPrimary && !hasBackup) return null;

    if (hasPrimary) {
      try {
        return await _readSource(_storePath);
      } on OutboxMigrationRequiredException {
        rethrow;
      } on OutboxCorruptException {
        await _preserveEvidence(_storePath);
      }
    }

    if (!hasBackup) throw const OutboxCorruptException();
    try {
      final loaded = await _readSource(_backupPath);
      await _restoreBackup();
      return loaded;
    } on OutboxMigrationRequiredException {
      rethrow;
    } on OutboxCorruptException {
      await _preserveEvidence(_backupPath);
      throw const OutboxCorruptException();
    }
  }

  Future<_LoadedOutbox> _readSource(String path) async {
    final bytes = await fileSystem.read(path);
    final envelope = _decodeEnvelope(bytes);
    if (envelope.schemaVersion > currentOutboxSchemaVersion) {
      throw const OutboxMigrationRequiredException();
    }
    final encrypted = _decodeEncryptedPayload(envelope.payload);
    if (_checksum(encrypted) != envelope.checksum) {
      throw const OutboxCorruptException();
    }
    final plaintext = await _encryption.decrypt(encrypted);
    final payload = _decodeObject(utf8.decode(plaintext));
    var version = envelope.schemaVersion;
    var migrated = false;
    while (version < currentOutboxSchemaVersion) {
      final migration = migrations.where(
        (item) => item.fromVersion == version,
      );
      if (migration.isEmpty) throw const OutboxMigrationRequiredException();
      final selected = migration.first;
      if (selected.toVersion != version + 1 ||
          selected.toVersion > currentOutboxSchemaVersion) {
        throw const OutboxMigrationRequiredException();
      }
      try {
        final migratedPayload = selected.migrate(
          Map<String, Object?>.from(payload),
        );
        jsonEncode(migratedPayload);
        payload
          ..clear()
          ..addAll(migratedPayload);
      } on OutboxMigrationRequiredException {
        rethrow;
      } on Object {
        throw const OutboxMigrationRequiredException();
      }
      version = selected.toVersion;
      migrated = true;
    }
    final snapshot = _decodeSnapshot(payload, wasMigrated: migrated);
    return _LoadedOutbox(
      snapshot: snapshot,
      generation: envelope.generation,
      wasMigrated: migrated,
    );
  }

  Future<void> _write(
    OutboxSnapshot next, {
    required int generation,
  }) async {
    securityPolicy.validate(next.toJson());
    final plaintext = utf8.encode(jsonEncode(next.toJson()));
    final encrypted = await _encryption.encrypt(plaintext);
    final envelope = OutboxEnvelope(
      schemaVersion: currentOutboxSchemaVersion,
      generation: generation,
      checksum: _checksum(encrypted),
      payload: base64Encode(encrypted),
    );
    final bytes = utf8.encode(jsonEncode(envelope.toJson()));
    capacity.validate(next, bytes.length);
    await fileSystem.write(_temporaryPath, bytes);
    if (await fileSystem.exists(_storePath)) {
      final previousPrimary = await fileSystem.read(_storePath);
      await fileSystem.write(_backupTemporaryPath, previousPrimary);
      await fileSystem.rename(_backupTemporaryPath, _backupPath);
    }
    await fileSystem.rename(_temporaryPath, _storePath);
  }

  Future<void> _restoreBackup() async {
    final backup = await fileSystem.read(_backupPath);
    await fileSystem.write(_temporaryPath, backup);
    await fileSystem.rename(_temporaryPath, _storePath);
  }

  Future<void> _preserveEvidence(String path) async {
    try {
      final evidence = '$path.corrupt.${_now().microsecondsSinceEpoch}';
      await fileSystem.copy(path, evidence);
    } on Object {
      // The original source remains untouched even if evidence export fails.
    }
  }

  Future<void> _releaseLock() async {
    if (!_ownsLock) return;
    await fileSystem.releaseLock(_lockPath);
    _ownsLock = false;
  }

  List<int> _decodeEncryptedPayload(String value) {
    try {
      return base64Decode(value);
    } on Object {
      throw const OutboxCorruptException();
    }
  }

  OutboxSnapshot _decodeSnapshot(
    Map<String, Object?> payload, {
    required bool wasMigrated,
  }) {
    try {
      final snapshot = OutboxSnapshot.fromJson(payload);
      if (wasMigrated && snapshot.unknownRecords.isNotEmpty) {
        throw const OutboxMigrationRequiredException();
      }
      securityPolicy.validate(snapshot.toJson());
      return snapshot;
    } on OutboxCorruptException {
      if (wasMigrated) {
        throw const OutboxMigrationRequiredException();
      }
      rethrow;
    } on DurableOutboxException {
      rethrow;
    } on Exception {
      if (wasMigrated) {
        throw const OutboxMigrationRequiredException();
      }
      throw const OutboxCorruptException();
    }
  }

  OutboxEnvelope _decodeEnvelope(List<int> bytes) {
    try {
      return OutboxEnvelope.fromJson(_decodeObject(utf8.decode(bytes)));
    } on DurableOutboxException {
      rethrow;
    } on Exception {
      throw const OutboxCorruptException();
    }
  }

  Map<String, Object?> _decodeObject(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<Object?, Object?>) {
        throw const OutboxCorruptException();
      }
      final result = <String, Object?>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String) throw const OutboxCorruptException();
        result[entry.key! as String] = entry.value;
      }
      return result;
    } on DurableOutboxException {
      rethrow;
    } on Exception {
      throw const OutboxCorruptException();
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await operation();
    } finally {
      done.complete();
    }
  }

  static String _checksum(List<int> bytes) {
    var hash = 2166136261;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _LoadedOutbox {
  const _LoadedOutbox({
    required this.snapshot,
    required this.generation,
    required this.wasMigrated,
  });

  final OutboxSnapshot snapshot;
  final int generation;
  final bool wasMigrated;
}
