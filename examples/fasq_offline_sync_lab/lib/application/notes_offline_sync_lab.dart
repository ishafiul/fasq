import 'dart:async';

import '../domain/note_mutation.dart';
import '../domain/offline_sync_lab_snapshot.dart';
import '../domain/offline_sync_runtime_snapshot.dart';
import 'offline_sync_gateway.dart';
import 'offline_sync_lab.dart';

/// Coordinates UI actions and activity history for the offline-sync lab.
///
/// This is the application module. It projects the gateway's runtime state
/// into immutable screen state and keeps presentation code independent from
/// Fasq and platform storage.
class NotesOfflineSyncLab implements OfflineSyncLab {
  NotesOfflineSyncLab({required OfflineSyncGateway gateway})
    : _gateway = gateway,
      _snapshot = _screenSnapshot(gateway.state) {
    _gatewaySubscription = _gateway.states.listen((_) => _publish());
    _publish();
  }

  final OfflineSyncGateway _gateway;
  final StreamController<OfflineSyncLabSnapshot> _snapshots =
      StreamController<OfflineSyncLabSnapshot>.broadcast(sync: true);
  final List<String> _events = <String>[];

  late final StreamSubscription<OfflineSyncRuntimeSnapshot>
  _gatewaySubscription;
  OfflineSyncLabSnapshot _snapshot;
  String? _lastCreatedNoteReference;
  bool _isDisposed = false;

  @override
  OfflineSyncLabSnapshot get snapshot => _snapshot;

  @override
  Stream<OfflineSyncLabSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> setOnline(bool online) async {
    await _gateway.setOnline(online);
    _record(online ? 'online' : 'offline');
    _publish();
  }

  @override
  CreateNoteCommand createNoteCommand(String title) {
    return CreateNoteCommand(title: title, owner: _gateway.state.account);
  }

  @override
  void retainCreatedNoteReference(String reference) {
    _lastCreatedNoteReference = reference;
  }

  @override
  UpdateNoteCommand dependentUpdateCommand() {
    final reference = _lastCreatedNoteReference;
    if (reference == null) {
      throw StateError('Create a note before updating it');
    }
    return UpdateNoteCommand(
      noteId: reference,
      title: 'Updated after create',
      owner: _gateway.state.account,
    );
  }

  @override
  Future<void> replay() async {
    final outcome = await _gateway.replay();
    _record(
      'replay executed ${outcome.executedCount}; '
      'blocked ${outcome.blockedCount}',
    );
    _publish();
  }

  @override
  Future<void> restart() async {
    await _gateway.restart();
    _record('reopened same encrypted outbox after restart');
    _publish();
  }

  @override
  Future<void> signInAs(String principalId) async {
    await _gateway.signInAs(principalId);
    _record('signed in as $principalId');
    _publish();
  }

  @override
  Future<void> failNextRequest() async {
    await _gateway.failNextRequest();
    _record('next replay request will fail terminally');
    _publish();
  }

  @override
  Future<void> retryFirstDeadLetter() async {
    await _gateway.retryFirstDeadLetter();
    _record('requested retry repair for the first dead letter');
    _publish();
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _gatewaySubscription.cancel();
    await _gateway.dispose();
    await _snapshots.close();
  }

  void _publish() {
    if (_isDisposed) return;
    final runtime = _gateway.state;
    _snapshot = OfflineSyncLabSnapshot(
      initialized: runtime.initialized,
      isOnline: runtime.isOnline,
      account: runtime.account,
      queueAggregateState: runtime.queueAggregateState,
      entries: runtime.entries,
      notes: runtime.notes,
      events: List.unmodifiable(_events),
      lastAction: _events.isEmpty ? null : _events.first,
    );
    if (!_snapshots.isClosed) _snapshots.add(_snapshot);
  }

  void _record(String event) {
    _events.insert(0, event);
    if (_events.length > 30) _events.removeLast();
  }

  static OfflineSyncLabSnapshot _screenSnapshot(
    OfflineSyncRuntimeSnapshot runtime,
  ) {
    return OfflineSyncLabSnapshot(
      initialized: runtime.initialized,
      isOnline: runtime.isOnline,
      account: runtime.account,
      queueAggregateState: runtime.queueAggregateState,
      entries: runtime.entries,
      notes: runtime.notes,
      events: const <String>[],
      lastAction: null,
    );
  }
}
