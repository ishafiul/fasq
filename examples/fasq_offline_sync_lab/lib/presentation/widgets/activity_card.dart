import 'package:flutter/material.dart';

import '../offline_sync_lab_scope.dart';
import 'lab_card.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.offlineSyncLabSnapshot.events;
    return LabCard(
      title: 'Event log',
      child: events.isEmpty
          ? const Text('No events yet.')
          : SelectableText(events.take(12).join('\n')),
    );
  }
}
