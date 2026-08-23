import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

import '../data/sync/notes_mutations.dart';
import '../domain/note_mutation.dart';
import 'offline_sync_lab_scope.dart';
import 'widgets/activity_card.dart';
import 'widgets/connection_card.dart';
import 'widgets/lab_card.dart';
import 'widgets/notes_card.dart';
import 'widgets/queue_card.dart';

class OfflineSyncLabScreen extends StatefulWidget {
  const OfflineSyncLabScreen({super.key});

  @override
  State<OfflineSyncLabScreen> createState() => _OfflineSyncLabScreenState();
}

class _OfflineSyncLabScreenState extends State<OfflineSyncLabScreen> {
  final _titleController = TextEditingController(text: 'Created while offline');
  Object? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = OfflineSyncLabScope.snapshotOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fasq Offline Sync Lab'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                state.isOnline ? Icons.cloud_done : Icons.cloud_off,
                size: 18,
              ),
              label: Text(state.isOnline ? 'online' : 'offline'),
            ),
          ),
        ],
      ),
      body: _LabBody(
        busy: _busy,
        error: _error,
        titleController: _titleController,
        onOnlineChanged: (online) =>
            _run(() => OfflineSyncLabScope.of(context).setOnline(online)),
        onAccountSelected: (account) =>
            _run(() => OfflineSyncLabScope.of(context).signInAs(account)),
        onRestart: () => _run(() => OfflineSyncLabScope.of(context).restart()),
        onReconnect: () =>
            _run(() => OfflineSyncLabScope.of(context).setOnline(true)),
        onFailNextRequest: () =>
            _run(() => OfflineSyncLabScope.of(context).failNextRequest()),
        onReplay: () => _run(() => OfflineSyncLabScope.of(context).replay()),
        onRepair: () =>
            _run(() => OfflineSyncLabScope.of(context).retryFirstDeadLetter()),
      ),
    );
  }
}

class _LabBody extends StatelessWidget {
  const _LabBody({
    required this.busy,
    required this.error,
    required this.titleController,
    required this.onOnlineChanged,
    required this.onAccountSelected,
    required this.onRestart,
    required this.onReconnect,
    required this.onFailNextRequest,
    required this.onReplay,
    required this.onRepair,
  });

  final bool busy;
  final Object? error;
  final TextEditingController titleController;
  final ValueChanged<bool> onOnlineChanged;
  final ValueChanged<String> onAccountSelected;
  final VoidCallback onRestart;
  final VoidCallback onReconnect;
  final VoidCallback onFailNextRequest;
  final VoidCallback onReplay;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final state = context.offlineSyncLabSnapshot;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Deterministic local transport. Real encrypted persistence.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Verify durable enqueue, restart recovery, ordered replay, dependency binding, auth scope, and explicit repair.',
        ),
        ConnectionCard(
          busy: busy,
          onOnlineChanged: onOnlineChanged,
          onAccountSelected: onAccountSelected,
        ),
        const QueueCard(),
        LabCard(
          title: 'Offline create → restart → reconnect',
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Note title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CreateNoteMutationButton(
                    titleController: titleController,
                    disabled: busy,
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onRestart,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restart / reopen'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : onReconnect,
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('Reconnect (auto replay)'),
                  ),
                ],
              ),
            ],
          ),
        ),
        LabCard(
          title: 'Dependency and repair',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DependentUpdateMutationButton(disabled: busy),
              OutlinedButton.icon(
                onPressed: busy ? null : onFailNextRequest,
                icon: const Icon(Icons.warning_amber),
                label: const Text('Fail next request'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onReplay,
                icon: const Icon(Icons.replay),
                label: const Text('Replay'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onRepair,
                icon: const Icon(Icons.build_circle_outlined),
                label: const Text('Retry dead letter'),
              ),
            ],
          ),
        ),
        const NotesCard(),
        const ActivityCard(),
        LabCard(
          title: error == null ? 'Lab state' : 'Action failed',
          child: SelectableText(
            error?.toString() ??
                'aggregate: ${state.queueAggregateState}\n'
                    'account: ${state.account}\n'
                    'entries: ${state.entries.length}\n'
                    'events: ${state.events.length}',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Native-only lab. File persistence and key storage are real; transport is local and deterministic. No exactly-once or guaranteed-background claim.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CreateNoteMutationButton extends StatelessWidget {
  const _CreateNoteMutationButton({
    required this.titleController,
    required this.disabled,
  });

  final TextEditingController titleController;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final lab = context.offlineSyncLab;
    return MutationBuilder<NoteMutationResult, CreateNoteCommand>(
      mutationKey: createNoteMutationKey,
      builder: (context, state, mutate) {
        final title = state.isError
            ? 'Create failed'
            : state.isQueued
            ? 'Create queued'
            : 'Create offline';
        return FilledButton.icon(
          onPressed: disabled || state.isLoading
              ? null
              : () async {
                  final value = titleController.text.trim();
                  if (value.isEmpty) return;
                  await lab.setOnline(false);
                  final submission = await mutate(lab.createNoteCommand(value));
                  final reference = submission.localReference;
                  if (reference != null) {
                    lab.retainCreatedNoteReference(reference);
                  }
                },
          icon: Icon(state.isError ? Icons.error_outline : Icons.cloud_off),
          label: Text(title),
        );
      },
    );
  }
}

class _DependentUpdateMutationButton extends StatelessWidget {
  const _DependentUpdateMutationButton({required this.disabled});

  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final lab = context.offlineSyncLab;
    return MutationBuilder<NoteMutationResult, UpdateNoteCommand>(
      mutationKey: updateNoteMutationKey,
      builder: (context, state, mutate) {
        return OutlinedButton.icon(
          onPressed: disabled || state.isLoading
              ? null
              : () => mutate(lab.dependentUpdateCommand()),
          icon: const Icon(Icons.account_tree),
          label: Text(state.isError ? 'Update failed' : 'Dependent update'),
        );
      },
    );
  }
}
