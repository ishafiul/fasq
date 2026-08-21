import 'package:fasq/fasq.dart';

import '../notes/note_commands.dart';
import '../notes/simulated_notes_transport.dart';

/// Fasq-specific mutation registrations for the notes feature.
///
/// This class owns serialization and transport adaptation. Queue lifecycle and
/// UI state stay in [NotesOfflineSyncLab].
class NotesMutations {
  NotesMutations({
    required SimulatedNotesTransport transport,
    required void Function(String event) onEvent,
    required void Function() onChanged,
  }) : _transport = transport,
       _onEvent = onEvent,
       _onChanged = onChanged {
    createNote = DurableMutation<NoteMutationResult, CreateNoteCommand>.define(
      key: 'offline_sync_lab.create_note',
      codec: JsonMutationCodec<CreateNoteCommand>(
        encoder: (command) => command.toJson(),
        decoder: CreateNoteCommand.fromJson,
      ),
      authPolicy: AuthPolicy.required,
      execute: _executeCreate,
      resultEncoder: (result) => result.toJson(),
    );
    updateNote = DurableMutation<NoteMutationResult, UpdateNoteCommand>.define(
      key: 'offline_sync_lab.update_note',
      codec: JsonMutationCodec<UpdateNoteCommand>(
        encoder: (command) => command.toJson(),
        decoder: UpdateNoteCommand.fromJson,
      ),
      authPolicy: AuthPolicy.required,
      execute: _executeUpdate,
      resultEncoder: (result) => result.toJson(),
    );
    definitions = List.unmodifiable(<DurableMutationDefinitionBase>[
      createNote,
      updateNote,
    ]);
  }

  final SimulatedNotesTransport _transport;
  final void Function(String event) _onEvent;
  final void Function() _onChanged;

  late final DurableMutation<NoteMutationResult, CreateNoteCommand> createNote;
  late final DurableMutation<NoteMutationResult, UpdateNoteCommand> updateNote;
  late final List<DurableMutationDefinitionBase> definitions;

  Future<NoteMutationResult> _executeCreate(CreateNoteCommand command) async {
    final result = _transport.create(command);
    _onEvent('transport created ${result.id}');
    _onChanged();
    return result;
  }

  Future<NoteMutationResult> _executeUpdate(UpdateNoteCommand command) async {
    final result = _transport.update(command);
    _onEvent('transport updated ${result.id}');
    _onChanged();
    return result;
  }
}
