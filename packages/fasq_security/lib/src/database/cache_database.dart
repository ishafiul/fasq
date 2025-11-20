import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CacheDatabase {
  CacheDatabase._(this._db, this._path);

  final NativeDatabase _db;
  final String _path;

  static String? _cachedPath;

  static Future<CacheDatabase> open(
      {String fileName = 'fasq_cache.sqlite'}) async {
    final file = await _resolveDatabaseFile(fileName);
    final database = NativeDatabase(
      file,
      logStatements: false,
      setup: (db) {
        // Configure PRAGMA settings
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA synchronous=NORMAL');
        db.execute('PRAGMA cache_size=10000');
        db.execute('PRAGMA busy_timeout=5000');

        // Create schema when database is opened
        db.execute('''
          CREATE TABLE IF NOT EXISTS cache_entries (
            cache_key TEXT PRIMARY KEY,
            encrypted_data BLOB NOT NULL,
            created_at INTEGER NOT NULL,
            expires_at INTEGER
          )
        ''');

        db.execute('''
          CREATE INDEX IF NOT EXISTS idx_cache_entries_expires
          ON cache_entries(expires_at)
        ''');
      },
    );
    final instance = CacheDatabase._(database, file.path);
    // The database will open automatically when first used
    // The setup callback will run when the database opens, creating the schema
    // We don't force it to open here to avoid circular dependency issues
    return instance;
  }

  static Future<File> _resolveDatabaseFile(String fileName) async {
    if (_cachedPath != null) {
      final file = File(_cachedPath!);
      await file.parent.create(recursive: true);
      return file;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, fileName));
      _cachedPath = file.path;
      return file;
    } on MissingPluginException {
      final fallbackDir =
          Directory(p.join(Directory.systemTemp.path, 'fasq_cache'));
      await fallbackDir.create(recursive: true);
      final file = File(p.join(fallbackDir.path, fileName));
      _cachedPath = file.path;
      return file;
    }
  }

  Future<Map<String, List<int>>> getCacheEntries(List<String> keys) async {
    if (keys.isEmpty) {
      return {};
    }

    final placeholders = List.filled(keys.length, '?').join(', ');
    final rows = await _db.runSelect(
      'SELECT cache_key, encrypted_data, expires_at '
      'FROM cache_entries '
      'WHERE cache_key IN ($placeholders)',
      keys,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <String, List<int>>{};

    for (final row in rows) {
      final expiresAt = row['expires_at'] as int?;
      if (expiresAt != null && expiresAt <= now) {
        continue;
      }

      final key = row['cache_key'] as String;
      final data = row['encrypted_data'] as Uint8List;
      result[key] = List<int>.from(data);
    }

    return result;
  }

  Future<void> insertCacheEntries(
    Map<String, List<int>> entries, {
    Map<String, DateTime?>? createdAt,
    Map<String, DateTime?>? expiresAt,
  }) async {
    if (entries.isEmpty) {
      return;
    }

    final now = DateTime.now();
    await _db.runCustom('BEGIN IMMEDIATE TRANSACTION');
    try {
      for (final entry in entries.entries) {
        final created = createdAt?[entry.key] ?? now;
        final expires = expiresAt?[entry.key];
        final createdAtMs = created.millisecondsSinceEpoch;
        final expiresAtMs = expires?.millisecondsSinceEpoch;

        await _db.runInsert(
          'INSERT OR REPLACE INTO cache_entries '
          '(cache_key, encrypted_data, created_at, expires_at) '
          'VALUES (?1, ?2, ?3, ?4)',
          [
            entry.key,
            Uint8List.fromList(entry.value),
            createdAtMs,
            expiresAtMs,
          ],
        );
      }
      await _db.runCustom('COMMIT');
    } catch (error) {
      await _db.runCustom('ROLLBACK');
      rethrow;
    }
  }

  Future<void> deleteCacheEntries(List<String> keys) async {
    if (keys.isEmpty) {
      return;
    }

    final placeholders = List.filled(keys.length, '?').join(', ');
    await _db.runDelete(
      'DELETE FROM cache_entries WHERE cache_key IN ($placeholders)',
      keys,
    );
  }

  Future<List<String>> getAllKeys() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.runSelect(
      'SELECT cache_key FROM cache_entries '
      'WHERE expires_at IS NULL OR expires_at > ?',
      [now],
    );

    return rows
        .map((row) => row['cache_key'] as String)
        .toList(growable: false);
  }

  Future<bool> exists(String key) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.runSelect(
      'SELECT 1 FROM cache_entries '
      'WHERE cache_key = ? AND (expires_at IS NULL OR expires_at > ?) '
      'LIMIT 1',
      [key, now],
    );
    return rows.isNotEmpty;
  }

  Future<void> clear() async {
    await _db.runDelete('DELETE FROM cache_entries', const []);
  }

  Future<CacheEntryMetadata?> getMetadata(String key) async {
    final rows = await _db.runSelect(
      'SELECT created_at, expires_at FROM cache_entries WHERE cache_key = ?',
      [key],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      row['created_at'] as int,
      isUtc: false,
    );
    final expiresAtRaw = row['expires_at'] as int?;

    return CacheEntryMetadata(
      createdAt: createdAt,
      expiresAt: expiresAtRaw != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtRaw)
          : null,
    );
  }

  Future<int> cleanupExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.runDelete(
      'DELETE FROM cache_entries WHERE expires_at IS NOT NULL AND expires_at <= ?',
      [now],
    );
  }

  Future<void> close() async {
    await _db.close();
  }

  String get path => _path;
}

class CacheEntryMetadata {
  const CacheEntryMetadata({
    required this.createdAt,
    required this.expiresAt,
  });

  final DateTime createdAt;
  final DateTime? expiresAt;
}
