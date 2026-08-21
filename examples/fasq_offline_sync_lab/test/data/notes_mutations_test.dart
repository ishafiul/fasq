import 'package:flutter_test/flutter_test.dart';

import 'package:fasq_offline_sync_lab/data/notes/simulated_notes_transport.dart';
import 'package:fasq_offline_sync_lab/data/sync/notes_mutations.dart';

void main() {
  test('exposes the lab mutations as typed Fasq definitions', () {
    final mutations = NotesMutations(
      transport: SimulatedNotesTransport(),
      onEvent: (_) {},
      onChanged: () {},
    );

    expect(mutations.definitions, hasLength(2));
    expect(mutations.createNote.key.key, 'offline_sync_lab:create_note:v1');
    expect(mutations.updateNote.key.key, 'offline_sync_lab:update_note:v1');
  });
}
