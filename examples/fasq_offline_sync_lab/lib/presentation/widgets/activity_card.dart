import 'package:flutter/material.dart';

import 'lab_card.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({required this.events, super.key});

  final List<String> events;

  @override
  Widget build(BuildContext context) {
    return LabCard(
      title: 'Event log',
      child: events.isEmpty
          ? const Text('No events yet.')
          : SelectableText(events.take(12).join('\n')),
    );
  }
}
