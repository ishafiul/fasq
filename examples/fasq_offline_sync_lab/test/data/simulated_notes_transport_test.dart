import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fasq_offline_sync_lab/data/notes/note_commands.dart';
import 'package:fasq_offline_sync_lab/data/notes/simulated_notes_transport.dart';

void main() {
  test('creates and updates a note through the local transport', () {
    final transport = SimulatedNotesTransport();

    final created = transport.create(
      const CreateNoteCommand(title: 'First title', owner: 'account-a'),
    );
    final noteId = created.id;

    final updated = transport.update(
      UpdateNoteCommand(
        noteId: noteId,
        title: 'Updated title',
        owner: 'account-a',
      ),
    );

    expect(updated.id, noteId);
    expect(transport.notes.single.title, 'Updated title');
  });

  test(
    'consumes one simulated failure and exposes a terminal adapter error',
    () {
      final transport = SimulatedNotesTransport();
      transport.failNextRequest();

      expect(
        () => transport.create(
          const CreateNoteCommand(title: 'Will fail', owner: 'account-a'),
        ),
        throwsA(isA<MutationAdapterException>()),
      );
      expect(transport.notes, isEmpty);
    },
  );
}
