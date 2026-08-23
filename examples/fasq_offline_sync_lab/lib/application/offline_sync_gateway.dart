import '../domain/offline_sync_operation.dart';
import '../domain/offline_sync_runtime_snapshot.dart';

/// Application-facing seam for the durable notes workflow.
///
/// The application layer knows the business operations it can request, but
/// not how Fasq, encryption, persistence, or transport are implemented.
abstract interface class OfflineSyncGateway {
  OfflineSyncRuntimeSnapshot get state;
  Stream<OfflineSyncRuntimeSnapshot> get states;

  Future<void> setOnline(bool online);
  Future<ReplayOutcome> replay();
  Future<void> restart();
  Future<void> signInAs(String principalId);
  Future<void> failNextRequest();
  Future<void> retryFirstDeadLetter();
  Future<void> dispose();
}
