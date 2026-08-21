import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';

import '../../application/offline_sync_lab.dart';
import '../../domain/offline_sync_lab_snapshot.dart';
import '../notes/note_commands.dart';
import '../notes/simulated_notes_transport.dart';
import 'notes_mutations.dart';

class NotesOfflineSyncLab implements OfflineSyncLab {
  NotesOfflineSyncLab({SimulatedNotesTransport? transport})
    : _transport = transport ?? SimulatedNotesTransport(),
      _networkStatus = NetworkStatus.instance {
    _mutations = NotesMutations(
      transport: _transport,
      onEvent: _record,
      onChanged: _publish,
    );
  }

  final SimulatedNotesTransport _transport;
  final NetworkStatus _networkStatus;
  late final NotesMutations _mutations;
  final StreamController<OfflineSyncLabSnapshot> _snapshots =
      StreamController<OfflineSyncLabSnapshot>.broadcast(sync: true);
  final List<String> _events = <String>[];

  Fasq? _fasq;
  InMemoryAuthSessionProvider? _auth;
  StreamSubscription<DurableQueueObservation>? _queueObservationSubscription;
  OfflineSyncLabSnapshot _snapshot = const OfflineSyncLabSnapshot.empty();
  AuthSessionSnapshot _session = const AuthSessionSnapshot.unknown();
  OperationId? _lastCreateOperationId;
  bool _isDisposed = false;
  int _repairSequence = 0;

  @override
  OfflineSyncLabSnapshot get snapshot => _snapshot;
  @override
  Stream<OfflineSyncLabSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> initialize() async {
    _checkNotDisposed();
    if (_fasq != null) return;
    _session = _readySession('account-a');
    _auth = InMemoryAuthSessionProvider(initial: _session);
    _networkStatus.setOnline(online: false);
    await _openSession();
    _record('opened encrypted durable outbox');
    _publish();
  }

  @override
  Future<void> setOnline(bool online) async {
    _checkNotDisposed();
    _networkStatus.setOnline(online: online);
    _record(online ? 'online' : 'offline');
    _publish();
  }

  @override
  Future<void> createNote(String title) async {
    final queue = _requireQueue();
    final session = await _requireReadySession();
    final acknowledgement = await queue.enqueue<CreateNoteCommand>(
      key: _mutations.createNote.key,
      variables: CreateNoteCommand(
        localId: 'local-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        owner: session.scope!.principalId,
      ),
      authScope: session.scope,
    );
    _lastCreateOperationId = acknowledgement.operationId;
    _record('queued create ${acknowledgement.operationId.value}');
    _publish();
  }

  @override
  Future<void> updateNoteAfterCreate() async {
    final parentOperationId = _lastCreateOperationId;
    if (parentOperationId == null) {
      throw StateError('Create a note before queueing its dependent update');
    }
    final queue = _requireQueue();
    final session = await _requireReadySession();
    final acknowledgement = await queue.enqueue<UpdateNoteCommand>(
      key: _mutations.updateNote.key,
      variables: UpdateNoteCommand(
        noteId: 'bound-after-create',
        title: 'Updated after create',
        owner: session.scope!.principalId,
      ),
      authScope: session.scope,
      dependencies: <MutationDependency>[
        MutationDependency(
          parentOperationId: parentOperationId,
          parentResultPath: 'id',
          childVariablePath: 'noteId',
        ),
      ],
    );
    _record('queued dependent update ${acknowledgement.operationId.value}');
    _publish();
  }

  @override
  Future<void> replay() async {
    final queue = _requireQueue();
    if (!_networkStatus.isOnline) {
      _record('replay skipped while offline; work remains pending');
      _publish();
      return;
    }
    final result = await queue.replay();
    _record(
      'replay executed ${result.executedOperationIds.length}; '
      'blocked ${result.blockedOperations.length}',
    );
    _publish();
  }

  @override
  Future<void> restart() async {
    _requireQueue();
    final auth = _auth!;
    final session = await auth.currentSession();
    await _closeSession();
    await auth.dispose();
    _session = session;
    _auth = InMemoryAuthSessionProvider(initial: _session);
    await _openSession();
    _record('reopened same encrypted outbox after restart');
    _publish();
  }

  @override
  Future<void> signInAs(String principalId) async {
    _checkNotDisposed();
    final auth = _auth;
    if (auth == null) {
      throw StateError('Initialize lab before changing account');
    }
    _session = _readySession(principalId);
    auth.update(_session);
    _record('signed in as $principalId');
    _publish();
  }

  @override
  Future<void> failNextRequest() async {
    _checkNotDisposed();
    _transport.failNextRequest();
    _record('next replay request will fail terminally');
    _publish();
  }

  @override
  Future<void> retryFirstDeadLetter() async {
    final queue = _requireQueue();
    final deadLetters = queue.observation.operations
        .where(
          (operation) =>
              operation.recordKind == DurableObservationRecordKind.deadLetter,
        )
        .toList(growable: false);
    final deadLetter = deadLetters.isEmpty ? null : deadLetters.first;
    if (deadLetter == null) {
      throw StateError('No dead letter is available for repair');
    }
    final session = await _requireReadySession();
    await queue.retryDeadLetter(
      operationId: deadLetter.operationId,
      idempotencyKey: 'lab-repair-${++_repairSequence}',
      currentAuthScope: session.scope,
    );
    _record('requested retry repair for ${deadLetter.operationId.value}');
    _publish();
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _closeSession();
    await _auth?.dispose();
    await _snapshots.close();
  }

  Future<Fasq> _openFasq() async {
    final auth = _auth;
    if (auth == null) throw StateError('Auth provider is not initialized');
    return Fasq.initialize(
      scope: const FasqDataScope.anonymous(),
      offlineSync: OfflineSync.secure(
        mutations: <DurableMutationDefinitionBase>[..._mutations.definitions],
        auth: auth,
        connectivity: _networkStatus,
      ),
    );
  }

  Future<void> _openSession() async {
    final fasq = await _openFasq();
    if (fasq.mutationQueue == null) {
      await fasq.close();
      throw StateError('Fasq offline sync did not create a mutation queue');
    }
    _fasq = fasq;
    _queueObservationSubscription = fasq.mutationQueue!.watch().listen(
      (_) => _publish(),
    );
  }

  Future<void> _closeSession() async {
    await _queueObservationSubscription?.cancel();
    _queueObservationSubscription = null;
    await _fasq?.close();
    _fasq = null;
  }

  Future<AuthSessionSnapshot> _requireReadySession() async {
    final session = await _auth?.currentSession();
    if (session?.status != AuthSessionStatus.ready || session?.scope == null) {
      throw StateError('A ready account is required');
    }
    return session!;
  }

  DurableMutationQueue _requireQueue() {
    _checkNotDisposed();
    final queue = _fasq?.mutationQueue;
    if (queue == null || !queue.isOpen) {
      throw StateError('Initialize lab before using sync controls');
    }
    return queue;
  }

  void _publish() {
    if (_isDisposed) return;
    final queue = _fasq?.mutationQueue;
    final observation = queue?.observation;
    _snapshot = OfflineSyncLabSnapshot(
      initialized: queue?.isOpen ?? false,
      isOnline: _networkStatus.isOnline,
      account: _session.scope?.principalId ?? 'none',
      queueAggregateState: observation?.aggregateState.name ?? 'idle',
      entries:
          observation?.operations.map(_mapEntry).toList(growable: false) ??
          const <LabQueueEntry>[],
      notes: _transport.notes,
      events: List.unmodifiable(_events),
      lastAction: _events.isEmpty ? null : _events.first,
    );
    if (!_snapshots.isClosed) _snapshots.add(_snapshot);
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

  void _record(String event) {
    _events.insert(0, event);
    if (_events.length > 30) _events.removeLast();
  }

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('Offline sync lab is disposed');
  }
}
