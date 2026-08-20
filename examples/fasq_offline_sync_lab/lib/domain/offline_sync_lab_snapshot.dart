import 'lab_note.dart';

enum LabRecordKind { active, deadLetter, unknown }

class LabQueueEntry {
  const LabQueueEntry({
    required this.operationId,
    required this.mutationKey,
    required this.state,
    required this.recordKind,
    required this.owner,
  });

  final String operationId;
  final String mutationKey;
  final String state;
  final LabRecordKind recordKind;
  final String? owner;
}

class OfflineSyncLabSnapshot {
  const OfflineSyncLabSnapshot({
    required this.initialized,
    required this.isOnline,
    required this.account,
    required this.queueAggregateState,
    required this.entries,
    required this.notes,
    required this.events,
    required this.lastAction,
  });

  const OfflineSyncLabSnapshot.empty()
    : initialized = false,
      isOnline = false,
      account = 'unknown',
      queueAggregateState = 'idle',
      entries = const <LabQueueEntry>[],
      notes = const <LabNote>[],
      events = const <String>[],
      lastAction = null;

  final bool initialized;
  final bool isOnline;
  final String account;
  final String queueAggregateState;
  final List<LabQueueEntry> entries;
  final List<LabNote> notes;
  final List<String> events;
  final String? lastAction;
}
