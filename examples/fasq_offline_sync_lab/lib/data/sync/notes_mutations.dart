import 'dart:async';

import 'package:fasq/fasq.dart';

import '../notes/note_commands.dart';
import '../notes/simulated_notes_transport.dart';

part 'notes_mutations.g.dart';

@FasqMutation(
  namespace: 'offline_sync_lab',
  name: 'create_note',
  authPolicy: AuthPolicy.required,
  encodeResult: true,
  factoryOnly: true,
)
Future<NoteMutationResult> createNote(CreateNoteCommand command) {
  throw UnsupportedError('The durable contract is executed by NotesMutations');
}

@FasqMutation(
  namespace: 'offline_sync_lab',
  name: 'update_note',
  authPolicy: AuthPolicy.required,
  encodeResult: true,
  factoryOnly: true,
  dependencies: [
    FasqMutationDependencyDeclaration(
      dependsOn: FasqMutationSource<NoteMutationResult, CreateNoteCommand>(
        createNote,
      ),
      fromResult: FasqMutationField<NoteMutationResult, String>('id'),
      toInput: FasqMutationField<UpdateNoteCommand, String>('noteId'),
    ),
  ],
)
Future<NoteMutationResult> updateNote(UpdateNoteCommand command) {
  throw UnsupportedError('The durable contract is executed by NotesMutations');
}

/// Fasq-specific mutation registrations for the notes feature.
///
/// The annotations are the durable contract. Code generation supplies the
/// typed handles; this adapter only owns transport execution and result
/// publication.
class NotesMutations {
  NotesMutations({required SimulatedNotesTransport transport})
    : _transport = transport {
    createNote = createNoteDurableHandle(execute: _executeCreate);
    updateNote = updateNoteDurableHandle(execute: _executeUpdate);
    definitions = List.unmodifiable(<DurableMutationDefinitionBase>[
      createNote,
      updateNote,
    ]);
  }

  final SimulatedNotesTransport _transport;
  final StreamController<NoteMutationResult> _results =
      StreamController<NoteMutationResult>.broadcast(sync: true);

  late final DurableMutation<NoteMutationResult, CreateNoteCommand> createNote;
  late final DurableMutation<NoteMutationResult, UpdateNoteCommand> updateNote;
  late final List<DurableMutationDefinitionBase> definitions;

  Stream<NoteMutationResult> get results => _results.stream;

  Future<NoteMutationResult> _executeCreate(CreateNoteCommand command) async {
    final result = _transport.create(command);
    _results.add(result);
    return result;
  }

  Future<NoteMutationResult> _executeUpdate(UpdateNoteCommand command) async {
    final result = _transport.update(command);
    _results.add(result);
    return result;
  }

  Future<void> dispose() => _results.close();
}
