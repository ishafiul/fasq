import 'package:flutter/material.dart';

import '../../domain/offline_sync_lab_snapshot.dart';
import 'lab_card.dart';

class QueueCard extends StatelessWidget {
  const QueueCard({required this.state, super.key});

  final OfflineSyncLabSnapshot state;

  @override
  Widget build(BuildContext context) {
    return LabCard(
      title: 'Durable queue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              _Metric('entries', '${state.entries.length}'),
              _Metric('aggregate', state.queueAggregateState),
              _Metric('notes', '${state.notes.length}'),
            ],
          ),
          const SizedBox(height: 8),
          if (state.entries.isEmpty)
            const Text('No active or dead-letter entries.')
          else
            ...state.entries.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.recordKind == LabRecordKind.deadLetter
                      ? Icons.error_outline
                      : Icons.sync_alt,
                ),
                title: Text(entry.mutationKey),
                subtitle: Text(
                  '${entry.state} · ${entry.recordKind.name} · ${entry.owner ?? 'anonymous'}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'));
}
