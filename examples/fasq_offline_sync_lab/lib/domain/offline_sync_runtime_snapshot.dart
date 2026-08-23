import 'lab_note.dart';
import 'offline_sync_lab_snapshot.dart';

/// Runtime data exposed by the data adapter to the application layer.
class OfflineSyncRuntimeSnapshot {
  const OfflineSyncRuntimeSnapshot({
    required this.initialized,
    required this.isOnline,
    required this.account,
    required this.queueAggregateState,
    required this.entries,
    required this.notes,
  });

  const OfflineSyncRuntimeSnapshot.empty()
    : initialized = false,
      isOnline = false,
      account = 'unknown',
      queueAggregateState = 'idle',
      entries = const <LabQueueEntry>[],
      notes = const <LabNote>[];

  final bool initialized;
  final bool isOnline;
  final String account;
  final String queueAggregateState;
  final List<LabQueueEntry> entries;
  final List<LabNote> notes;
}
