import 'package:fasq/fasq.dart';

import '../../domain/lab_note.dart';
import 'note_commands.dart';

/// Deterministic local transport. It models server effects without network IO.
class SimulatedNotesTransport {
  final Map<String, LabNote> _notes = <String, LabNote>{};
  int _nextId = 1;
  bool _shouldFailNextRequest = false;

  List<LabNote> get notes => List.unmodifiable(_notes.values);

  void failNextRequest() => _shouldFailNextRequest = true;

  NoteMutationResult create(CreateNoteCommand command) {
    _throwIfFailureRequested();
    final id = 'server-note-${_nextId++}';
    _notes[id] = LabNote(id: id, title: command.title, owner: command.owner);
    return NoteMutationResult(id: id, localId: command.localId);
  }

  NoteMutationResult update(UpdateNoteCommand command) {
    _throwIfFailureRequested();
    final note = _notes[command.noteId];
    if (note == null) {
      throw const MutationAdapterException(
        MutationAdapterFailure(
          category: MutationFailureCategory.business,
          messageKey: 'offline_lab.note_missing',
          disposition: MutationFailureDisposition.terminal,
          executionPhase: MutationExecutionPhase.started,
          repairable: true,
        ),
      );
    }
    _notes[command.noteId] = LabNote(
      id: note.id,
      title: command.title,
      owner: note.owner,
    );
    return NoteMutationResult(id: note.id, title: command.title);
  }

  void _throwIfFailureRequested() {
    if (!_shouldFailNextRequest) return;
    _shouldFailNextRequest = false;
    throw const MutationAdapterException(
      MutationAdapterFailure(
        category: MutationFailureCategory.business,
        messageKey: 'offline_lab.simulated_failure',
        disposition: MutationFailureDisposition.terminal,
        executionPhase: MutationExecutionPhase.started,
        repairable: true,
      ),
    );
  }
}
