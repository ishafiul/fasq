import 'package:flutter/material.dart';

import '../../domain/lab_note.dart';
import 'lab_card.dart';

class NotesCard extends StatelessWidget {
  const NotesCard({required this.notes, super.key});

  final List<LabNote> notes;

  @override
  Widget build(BuildContext context) {
    return LabCard(
      title: 'Server notes',
      child: notes.isEmpty
          ? const Text('No server notes yet.')
          : Column(
              children: notes
                  .map(
                    (note) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(note.title),
                      subtitle: Text('${note.id} · ${note.owner}'),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}
