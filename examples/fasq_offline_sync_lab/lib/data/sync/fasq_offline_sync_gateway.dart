import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';

import '../../application/offline_sync_gateway.dart';
import '../../domain/lab_note.dart';
import '../../domain/offline_sync_operation.dart';
import '../../domain/offline_sync_lab_snapshot.dart';
import '../../domain/offline_sync_runtime_snapshot.dart';
import '../notes/notes_query.dart';
import '../notes/simulated_notes_transport.dart';
import 'notes_mutations.dart';

typedef FasqFactory = Future<Fasq> Function();
typedef FasqRuntimeChanged = void Function(Fasq runtime);

/// Fasq-backed adapter for the application's durable notes workflow.
///
/// This is the only module that knows how the queue, secure persistence,
/// account scope, query cache, and simulated transport fit together.
class FasqOfflineSyncGateway implements OfflineSyncGateway {
  FasqOfflineSyncGateway._({
    required Fasq fasq,
    required InMemoryAuthSessionProvider auth,
    required String activeAccount,
    required NetworkStatus networkStatus,
    required SimulatedNotesTransport transport,
    required NotesMutations mutations,
    required FasqFactory openFasq,
    required FasqRuntimeChanged onRuntimeChanged,
  }) : _fasq = fasq,
       _auth = auth,
       _activeAccount = activeAccount,
       _networkStatus = networkStatus,
       _transport = transport,
       _mutations = mutations,
       _openFasq = openFasq,
       _onRuntimeChanged = onRuntimeChanged;

  static Future<FasqOfflineSyncGateway> create({
    required Fasq fasq,
    required InMemoryAuthSessionProvider auth,
    required String activeAccount,
    required NetworkStatus networkStatus,
    required SimulatedNotesTransport transport,
    required NotesMutations mutations,
    required FasqFactory openFasq,
    required FasqRuntimeChanged onRuntimeChanged,
  }) async {
    final gateway = FasqOfflineSyncGateway._(
      fasq: fasq,
      auth: auth,
      activeAccount: activeAccount,
      networkStatus: networkStatus,
      transport: transport,
      mutations: mutations,
      openFasq: openFasq,
      onRuntimeChanged: onRuntimeChanged,
    );
    await gateway._attachRuntime();
    return gateway;
  }

  final InMemoryAuthSessionProvider _auth;
  String _activeAccount;
  final NetworkStatus _networkStatus;
  final SimulatedNotesTransport _transport;
  final NotesMutations _mutations;
  final FasqFactory _openFasq;
  final FasqRuntimeChanged _onRuntimeChanged;
  final StreamController<OfflineSyncRuntimeSnapshot> _states =
      StreamController<OfflineSyncRuntimeSnapshot>.broadcast(sync: true);

  Fasq _fasq;
  StreamSubscription<DurableQueueObservation>? _queueSubscription;
  StreamSubscription<QueryState<List<LabNote>>>? _notesSubscription;
  NotesQuery? _notesQuery;
  OfflineSyncRuntimeSnapshot _state = const OfflineSyncRuntimeSnapshot.empty();
  int _repairSequence = 0;
  bool _isDisposed = false;

  @override
  OfflineSyncRuntimeSnapshot get state => _state;

  @override
  Stream<OfflineSyncRuntimeSnapshot> get states => _states.stream;

  @override
  Future<void> setOnline(bool online) async {
    _checkNotDisposed();
    _networkStatus.setOnline(online: online);
    _publish();
  }

  @override
  Future<ReplayOutcome> replay() async {
    final queue = _requireQueue();
    if (!_networkStatus.isOnline) {
      _publish();
      return const ReplayOutcome(executedCount: 0, blockedCount: 0);
    }
    final result = await queue.replay();
    await _notesQuery?.refresh(forceRefetch: true);
    _publish();
    return ReplayOutcome(
      executedCount: result.executedOperationIds.length,
      blockedCount: result.blockedOperations.length,
    );
  }

  @override
  Future<void> restart() async {
    _requireQueue();
    await _closeFasq();
    final nextRuntime = await _openFasq();
    _fasq = nextRuntime;
    try {
      await _attachRuntime();
      _onRuntimeChanged(nextRuntime);
    } on Object {
      await _closeFasq();
      rethrow;
    }
  }

  @override
  Future<void> signInAs(String principalId) async {
    _checkNotDisposed();
    _activeAccount = principalId;
    _auth.update(_readySession(principalId));
    await _detachNotesQuery();
    await _attachNotesQuery();
    _publish();
  }

  @override
  Future<void> failNextRequest() async {
    _checkNotDisposed();
    _transport.failNextRequest();
    _publish();
  }

  @override
  Future<void> retryFirstDeadLetter() async {
    final queue = _requireQueue();
    DurableOperationObservation? deadLetter;
    for (final operation in queue.observation.operations) {
      if (operation.recordKind == DurableObservationRecordKind.deadLetter) {
        deadLetter = operation;
        break;
      }
    }
    if (deadLetter == null) {
      throw StateError('No dead letter is available for repair');
    }
    final session = await _requireReadySession();
    await queue.retryDeadLetter(
      operationId: deadLetter.operationId,
      idempotencyKey: 'lab-repair-${++_repairSequence}',
      currentAuthScope: session.scope,
    );
    _publish();
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _closeFasq();
    await _auth.dispose();
    await _mutations.dispose();
    await _states.close();
  }

  Future<void> _attachRuntime() async {
    final queue = _fasq.mutationQueue;
    if (queue == null) {
      throw StateError('Fasq offline sync did not create a mutation queue');
    }
    await _attachNotesQuery();
    _queueSubscription = queue.watch().listen((_) => _publish());
    _publish();
  }

  Future<void> _attachNotesQuery() async {
    final owner = (await _requireReadySession()).scope!.principalId;
    final notesQuery = NotesQuery(
      client: _fasq.queryClient,
      transport: _transport,
      owner: owner,
      mutationResults: _mutations.results,
    );
    _notesQuery = notesQuery;
    _notesSubscription = notesQuery.states.listen((_) => _publish());
  }

  Future<void> _detachNotesQuery() async {
    await _notesSubscription?.cancel();
    _notesSubscription = null;
    await _notesQuery?.dispose();
    _notesQuery = null;
  }

  Future<void> _closeFasq() async {
    await _queueSubscription?.cancel();
    _queueSubscription = null;
    await _detachNotesQuery();
    await _fasq.close();
  }

  DurableMutationQueue _requireQueue() {
    _checkNotDisposed();
    final queue = _fasq.mutationQueue;
    if (queue == null || !queue.isOpen) {
      throw StateError('Initialize lab before using sync controls');
    }
    return queue;
  }

  Future<AuthSessionSnapshot> _requireReadySession() async {
    final session = await _auth.currentSession();
    if (session.status != AuthSessionStatus.ready || session.scope == null) {
      throw StateError('A ready account is required');
    }
    return session;
  }

  void _publish() {
    if (_isDisposed) return;
    final queue = _fasq.mutationQueue;
    final observation = queue?.observation;
    _state = OfflineSyncRuntimeSnapshot(
      initialized: queue?.isOpen ?? false,
      isOnline: _networkStatus.isOnline,
      account: _activeAccount,
      queueAggregateState: observation?.aggregateState.name ?? 'idle',
      entries:
          observation?.operations.map(_mapEntry).toList(growable: false) ??
          const <LabQueueEntry>[],
      notes: _notesQuery?.notes ?? const <LabNote>[],
    );
    if (!_states.isClosed) _states.add(_state);
  }

  LabQueueEntry _mapEntry(DurableOperationObservation operation) {
    return LabQueueEntry(
      operationId: operation.operationId.value,
      mutationKey: operation.mutationKey.key,
      state: operation.state.name,
      recordKind: switch (operation.recordKind) {
        DurableObservationRecordKind.active => LabRecordKind.active,
        DurableObservationRecordKind.deadLetter => LabRecordKind.deadLetter,
        DurableObservationRecordKind.unknown => LabRecordKind.unknown,
      },
      owner: operation.authScope?.principalId,
    );
  }

  AuthSessionSnapshot _readySession(String principalId) {
    return AuthSessionSnapshot.ready(
      AuthScope(
        principalId: principalId,
        tenantId: 'demo',
        authRealm: 'offline-sync-lab',
      ),
    );
  }

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('Offline sync gateway is disposed');
  }
}
