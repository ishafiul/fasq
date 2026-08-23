import 'package:flutter/material.dart';

import '../offline_sync_lab_scope.dart';
import 'lab_card.dart';

class NotesCard extends StatelessWidget {
  const NotesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final notes = context.offlineSyncLabSnapshot.notes;
    return LabCard(
      title: 'Durable notes query',
      child: notes.isEmpty
          ? const Text('No cached notes yet.')
          : Column(
              children: notes
                  .map(
                    (note) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(note.title),
                      subtitle: Text(
                        '${note.id} · ${note.owner}'
                        '${note.isOptimistic ? ' · local optimistic' : ' · server'}',
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}
