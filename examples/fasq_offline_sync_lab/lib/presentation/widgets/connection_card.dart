import 'package:flutter/material.dart';

import '../offline_sync_lab_scope.dart';
import 'lab_card.dart';

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    required this.busy,
    required this.onOnlineChanged,
    required this.onAccountSelected,
    super.key,
  });

  final bool busy;
  final ValueChanged<bool> onOnlineChanged;
  final ValueChanged<String> onAccountSelected;

  @override
  Widget build(BuildContext context) {
    final state = context.offlineSyncLabSnapshot;
    return LabCard(
      title: 'Connectivity and identity',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.isOnline
                      ? 'Replay is allowed'
                      : 'Mutations remain durable while offline',
                ),
              ),
              Switch(
                value: state.isOnline,
                onChanged: busy ? null : onOnlineChanged,
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Text('Account: ${state.account}'),
              const Spacer(),
              OutlinedButton(
                onPressed: busy ? null : () => onAccountSelected('account-a'),
                child: const Text('Account A'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: busy ? null : () => onAccountSelected('account-b'),
                child: const Text('Account B'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
