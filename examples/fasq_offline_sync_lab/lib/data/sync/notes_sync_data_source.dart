import 'dart:async';

import 'package:fasq/fasq.dart';

import '../../application/offline_sync_lab_data_source.dart';
import '../../domain/offline_sync_lab_snapshot.dart';
import '../notes/note_commands.dart';
import '../notes/simulated_notes_transport.dart';
import '../security/secure_outbox_factory.dart';

class NotesSyncDataSource implements OfflineSyncLabDataSource {
  NotesSyncDataSource({
    required SecureOutboxFactory outboxFactory,
    SimulatedNotesTransport? transport,
  }) : _outboxFactory = outboxFactory,
       _transport = transport ?? SimulatedNotesTransport();

  static final _createNoteKey = MutationKey(
    namespace: 'offline_sync_lab',
    name: 'create_note',
  );
  static final _updateNoteKey = MutationKey(
    namespace: 'offline_sync_lab',
    name: 'update_note',
  );

  final SecureOutboxFactory _outboxFactory;
  final SimulatedNotesTransport _transport;
  final StreamController<OfflineSyncLabSnapshot> _snapshots =
      StreamController<OfflineSyncLabSnapshot>.broadcast(sync: true);
  final List<String> _events = <String>[];

  DurableMutationQueue? _queue;
  InMemoryAuthSessionProvider? _auth;
  OfflineSyncLabSnapshot _snapshot = const OfflineSyncLabSnapshot.empty();
  AuthSessionSnapshot _session = const AuthSessionSnapshot.unknown();
  OperationId? _lastCreateOperationId;
  bool _isOnline = false;
  bool _isDisposed = false;
  int _repairSequence = 0;

  @override
  OfflineSyncLabSnapshot get snapshot => _snapshot;
  @override
  Stream<OfflineSyncLabSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> initialize() async {
    _checkNotDisposed();
    if (_queue != null) return;
    _session = _readySession('account-a');
    _auth = InMemoryAuthSessionProvider(initial: _session);
    _queue = await _openQueue();
    _record('opened encrypted durable outbox');
    _publish();
  }

  @override
  Future<void> setOnline(bool online) async {
    _checkNotDisposed();
    _isOnline = online;
    _record(online ? 'online' : 'offline');
    _publish();
  }

  @override
  Future<void> createNote(String title) async {
    final queue = _requireQueue();
    final session = await _requireReadySession();
    final acknowledgement = await queue.enqueue<CreateNoteCommand>(
      key: _createNoteKey,
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
      key: _updateNoteKey,
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
    if (!_isOnline) {
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
    final queue = _requireQueue();
    final auth = _auth!;
    final session = await auth.currentSession();
    await queue.close();
    await auth.dispose();
    _session = session;
    _auth = InMemoryAuthSessionProvider(initial: _session);
    _queue = await _openQueue();
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
    final deadLetters = queue.snapshot.deadLetters;
    final deadLetter = deadLetters.isEmpty ? null : deadLetters.first;
    if (deadLetter == null) {
      throw StateError('No dead letter is available for repair');
    }
    final session = await _requireReadySession();
    await queue.retryDeadLetter(
      operationId: deadLetter.operation.operationId,
      idempotencyKey: 'lab-repair-${++_repairSequence}',
      currentAuthScope: session.scope,
    );
    _record(
      'requested retry repair for ${deadLetter.operation.operationId.value}',
    );
    _publish();
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _queue?.close();
    await _auth?.dispose();
    await _snapshots.close();
  }

  Future<DurableMutationQueue> _openQueue() async {
    final auth = _auth;
    if (auth == null) throw StateError('Auth provider is not initialized');
    final queue = DurableMutationQueue(
      store: await _outboxFactory.open(),
      authSessionProvider: auth,
      isOnline: () => _isOnline,
    );
    _registerMutations(queue);
    await queue.open();
    return queue;
  }

  void _registerMutations(DurableMutationQueue queue) {
    queue
      ..register<Map<String, Object?>, CreateNoteCommand>(
        key: _createNoteKey,
        codec: JsonMutationCodec<CreateNoteCommand>(
          encoder: (command) => command.toJson(),
          decoder: CreateNoteCommand.fromJson,
        ),
        authPolicy: AuthPolicy.required,
        mutationFn: _executeCreate,
        resultEncoder: (result) => result,
      )
      ..register<Map<String, Object?>, UpdateNoteCommand>(
        key: _updateNoteKey,
        codec: JsonMutationCodec<UpdateNoteCommand>(
          encoder: (command) => command.toJson(),
          decoder: UpdateNoteCommand.fromJson,
        ),
        authPolicy: AuthPolicy.required,
        mutationFn: _executeUpdate,
        resultEncoder: (result) => result,
      );
  }

  Future<Map<String, Object?>> _executeCreate(CreateNoteCommand command) async {
    final result = _transport.create(command);
    _record('transport created ${result['id']}');
    _publish();
    return result;
  }

  Future<Map<String, Object?>> _executeUpdate(UpdateNoteCommand command) async {
    final result = _transport.update(command);
    _record('transport updated ${result['id']}');
    _publish();
    return result;
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
    final queue = _queue;
    if (queue == null || !queue.isOpen) {
      throw StateError('Initialize lab before using sync controls');
    }
    return queue;
  }

  void _publish() {
    if (_isDisposed) return;
    final queue = _queue;
    final observation = queue == null
        ? null
        : buildQueueObservation(
            queue.snapshot,
            filter: DurableOperationFilter(scopeBound: false),
          );
    _snapshot = OfflineSyncLabSnapshot(
      initialized: queue?.isOpen ?? false,
      isOnline: _isOnline,
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
