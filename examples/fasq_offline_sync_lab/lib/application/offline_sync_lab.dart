import '../domain/note_mutation.dart';
import '../domain/offline_sync_lab_snapshot.dart';

/// UI-facing use cases for the offline-sync walkthrough.
abstract interface class OfflineSyncLab {
  OfflineSyncLabSnapshot get snapshot;
  Stream<OfflineSyncLabSnapshot> get snapshots;

  Future<void> dispose();
  Future<void> setOnline(bool online);
  CreateNoteCommand createNoteCommand(String title);
  void retainCreatedNoteReference(String reference);
  UpdateNoteCommand dependentUpdateCommand();
  Future<void> replay();
  Future<void> restart();
  Future<void> signInAs(String principalId);
  Future<void> failNextRequest();
  Future<void> retryFirstDeadLetter();
}
