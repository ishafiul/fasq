import '../domain/offline_sync_lab_snapshot.dart';

/// UI-facing use cases for the offline-sync walkthrough.
abstract interface class OfflineSyncLab {
  OfflineSyncLabSnapshot get snapshot;
  Stream<OfflineSyncLabSnapshot> get snapshots;

  Future<void> initialize();
  Future<void> dispose();
  Future<void> setOnline(bool online);
  Future<void> createNote(String title);
  Future<void> updateNoteAfterCreate();
  Future<void> replay();
  Future<void> restart();
  Future<void> signInAs(String principalId);
  Future<void> failNextRequest();
  Future<void> retryFirstDeadLetter();
}
