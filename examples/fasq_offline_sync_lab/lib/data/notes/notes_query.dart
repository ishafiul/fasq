import 'package:fasq/fasq.dart';
import 'dart:async';

import '../../domain/lab_note.dart';
import 'note_commands.dart';
import 'notes_query_keys.dart';
import 'simulated_notes_transport.dart';

/// Query and cache seam for one account's notes.
///
/// The query itself is ordinary Fasq [Query] state. [QueryPersistence.secure]
/// makes its cache durable at composition time; this module owns the feature
/// rules for optimistic list edits and server-result reconciliation.
class NotesQuery {
  NotesQuery({
    required QueryClient client,
    required SimulatedNotesTransport transport,
    required String owner,
    Stream<NoteMutationResult>? mutationResults,
  }) : _client = client,
       _transport = transport,
       _owner = owner,
       _queryKey = NotesQueryKeys.notes(owner) {
    _query = _client.getQuery<List<LabNote>>(
      _queryKey,
      queryFn: () async => _transport.fetchNotes(_owner),
      options: QueryOptions(
        staleTime: Duration(minutes: 5),
        cacheTime: Duration(days: 1),
      ),
    );
    if (mutationResults != null) {
      _mutationResultSubscription = mutationResults.listen(reconcile);
    }
  }

  static final PersistenceOptions persistenceOptions = PersistenceOptions(
    enabled: true,
    codecRegistry: registerQueryKeySerializers(const CacheDataCodecRegistry()),
  );

  final QueryClient _client;
  final SimulatedNotesTransport _transport;
  final String _owner;
  final QueryKey _queryKey;
  late final Query<List<LabNote>> _query;
  StreamSubscription<NoteMutationResult>? _mutationResultSubscription;

  /// Current query state, including restored durable cache data.
  QueryState<List<LabNote>> get state => _query.state;

  /// Emits cache, optimistic, and server-result changes.
  Stream<QueryState<List<LabNote>>> get states => _query.stream;

  /// Current list value, or an empty list before first data arrives.
  List<LabNote> get notes {
    final value = state.data ?? _client.getQueryData<List<LabNote>>(_queryKey);
    return List.unmodifiable(value ?? const <LabNote>[]);
  }

  /// Fetches authoritative notes from the transport.
  Future<void> refresh({bool forceRefetch = false}) {
    return _query.fetch(forceRefetch: forceRefetch);
  }

  /// Adds a local note immediately after durable enqueue succeeds.
  void addOptimisticCreate({required String localId, required String title}) {
    _write([
      ...notes,
      LabNote(id: localId, title: title, owner: _owner, isOptimistic: true),
    ]);
  }

  /// Applies a local title change before its queued update reaches the server.
  void updateOptimisticTitle({required String noteId, required String title}) {
    _write(
      notes
          .map(
            (note) => note.id == noteId
                ? LabNote(
                    id: note.id,
                    title: title,
                    owner: note.owner,
                    isOptimistic: true,
                  )
                : note,
          )
          .toList(growable: false),
    );
  }

  /// Reconciles one authoritative mutation result into the visible list.
  void reconcile(NoteMutationResult result) {
    if (result.owner != _owner) return;

    final existing = notes.where((note) => note.id == result.id);
    final existingNote = existing.isEmpty ? null : existing.first;
    final title = result.title ?? existingNote?.title;
    if (title == null) return;

    final serverNote = LabNote(
      id: result.id,
      title: title,
      owner: result.owner,
    );
    _write([...notes.where((note) => note.id != result.id), serverNote]);
  }

  void _write(List<LabNote> value) {
    _client.setQueryData<List<LabNote>>(_queryKey, List.unmodifiable(value));
  }

  Future<void> dispose() async {
    await _mutationResultSubscription?.cancel();
  }
}
