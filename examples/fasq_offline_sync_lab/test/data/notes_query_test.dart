import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fasq_offline_sync_lab/data/notes/notes_query.dart';
import 'package:fasq_offline_sync_lab/data/notes/simulated_notes_transport.dart';
import 'package:fasq_offline_sync_lab/data/notes/note_commands.dart';

void main() {
  late QueryClient client;
  late SimulatedNotesTransport transport;

  setUp(() {
    client = QueryClient.create();
    transport = SimulatedNotesTransport();
  });

  tearDown(() async {
    await client.dispose();
  });

  test(
    'updates cached list optimistically and accepts server result',
    () async {
      final query = NotesQuery(
        client: client,
        transport: transport,
        owner: 'account-a',
      );

      await query.refresh(forceRefetch: true);
      query.addOptimisticCreate(localId: 'local-1', title: 'Offline title');

      expect(query.notes.single.id, 'local-1');
      expect(query.notes.single.isOptimistic, isTrue);

      query.reconcile(
        const NoteMutationResult(
          id: 'local-1',
          title: 'Server title',
          owner: 'account-a',
        ),
      );

      expect(query.notes, hasLength(1));
      expect(query.notes.single.id, 'local-1');
      expect(query.notes.single.title, 'Server title');
      expect(query.notes.single.isOptimistic, isFalse);
    },
  );

  test('refresh reads authoritative owner-scoped server list', () async {
    transport.create(
      const CreateNoteCommand(title: 'Account A note', owner: 'account-a'),
    );
    transport.create(
      const CreateNoteCommand(title: 'Account B note', owner: 'account-b'),
    );

    final query = NotesQuery(
      client: client,
      transport: transport,
      owner: 'account-a',
    );
    await query.refresh(forceRefetch: true);

    expect(query.notes, hasLength(1));
    expect(query.notes.single.title, 'Account A note');
  });
}
