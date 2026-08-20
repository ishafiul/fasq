import 'offline_sync_lab_data_source.dart';
import '../domain/offline_sync_lab_snapshot.dart';

/// Small application interface consumed by presentation code.
class OfflineSyncLabController {
  OfflineSyncLabController({required OfflineSyncLabDataSource dataSource})
    : _dataSource = dataSource;

  final OfflineSyncLabDataSource _dataSource;

  OfflineSyncLabSnapshot get state => _dataSource.snapshot;
  Stream<OfflineSyncLabSnapshot> get states => _dataSource.snapshots;

  Future<void> initialize() => _dataSource.initialize();
  Future<void> dispose() => _dataSource.dispose();
  Future<void> setOnline(bool online) => _dataSource.setOnline(online);
  Future<void> createNote(String title) => _dataSource.createNote(title);
  Future<void> updateNoteAfterCreate() => _dataSource.updateNoteAfterCreate();
  Future<void> replay() => _dataSource.replay();
  Future<void> restart() => _dataSource.restart();
  Future<void> signInAs(String principalId) =>
      _dataSource.signInAs(principalId);
  Future<void> failNextRequest() => _dataSource.failNextRequest();
  Future<void> retryFirstDeadLetter() => _dataSource.retryFirstDeadLetter();
}
