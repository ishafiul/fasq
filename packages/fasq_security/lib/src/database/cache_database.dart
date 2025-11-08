import 'dart:io';
import 'dart:typed_data';

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
    );
    final instance = CacheDatabase._(database, file.path);
    await instance._createSchema();
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

  Future<void> _createSchema() async {
    await _db.runCustom('''
      CREATE TABLE IF NOT EXISTS cache_entries (
        cache_key TEXT PRIMARY KEY,
        encrypted_data BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER
      )
    ''');

    await _db.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_cache_entries_expires
      ON cache_entries(expires_at)
    ''');
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

  Future<void> insertCacheEntries(Map<String, List<int>> entries) async {
    if (entries.isEmpty) {
      return;
    }

    final createdAt = DateTime.now();
    for (final entry in entries.entries) {
      final createdAtMs = createdAt.millisecondsSinceEpoch;
      final expiresAt =
          createdAt.add(const Duration(days: 7)).millisecondsSinceEpoch;

      await _db.runInsert(
        'INSERT OR REPLACE INTO cache_entries '
        '(cache_key, encrypted_data, created_at, expires_at) '
        'VALUES (?1, ?2, ?3, ?4)',
        [
          entry.key,
          Uint8List.fromList(entry.value),
          createdAtMs,
          expiresAt,
        ],
      );
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
