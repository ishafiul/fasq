import 'dart:async';

import 'package:flutter/material.dart';

import '../application/offline_sync_lab.dart';
import '../domain/offline_sync_lab_snapshot.dart';
import 'widgets/activity_card.dart';
import 'widgets/connection_card.dart';
import 'widgets/lab_card.dart';
import 'widgets/notes_card.dart';
import 'widgets/queue_card.dart';

class OfflineSyncLabScreen extends StatefulWidget {
  const OfflineSyncLabScreen({required this.lab, super.key});

  final OfflineSyncLab lab;

  @override
  State<OfflineSyncLabScreen> createState() => _OfflineSyncLabScreenState();
}

class _OfflineSyncLabScreenState extends State<OfflineSyncLabScreen> {
  final _titleController = TextEditingController(text: 'Created while offline');
  Object? _error;
  bool _busy = true;

  OfflineSyncLab get _lab => widget.lab;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      await _lab.initialize();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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

  Future<void> _createOffline() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    await _run(() async {
      await _lab.setOnline(false);
      await _lab.createNote(title);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    unawaited(_lab.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OfflineSyncLabSnapshot>(
      stream: _lab.snapshots,
      initialData: _lab.snapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _lab.snapshot;
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
          body: _busy && !state.initialized
              ? const Center(child: CircularProgressIndicator())
              : !state.initialized
              ? _InitializationCard(error: _error, onRetry: _initialize)
              : _LabBody(
                  state: state,
                  busy: _busy,
                  error: _error,
                  titleController: _titleController,
                  onOnlineChanged: (online) =>
                      _run(() => _lab.setOnline(online)),
                  onAccountSelected: (account) =>
                      _run(() => _lab.signInAs(account)),
                  onCreateOffline: _createOffline,
                  onRestart: () => _run(_lab.restart),
                  onReconnect: () => _run(() => _lab.setOnline(true)),
                  onDependentUpdate: () => _run(_lab.updateNoteAfterCreate),
                  onFailNextRequest: () => _run(_lab.failNextRequest),
                  onReplay: () => _run(_lab.replay),
                  onRepair: () => _run(_lab.retryFirstDeadLetter),
                ),
        );
      },
    );
  }
}

class _InitializationCard extends StatelessWidget {
  const _InitializationCard({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lab is not initialized',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error == null
                      ? 'Initialize the encrypted durable outbox before using sync controls.'
                      : 'Initialization failed: $error',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Initialize lab'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabBody extends StatelessWidget {
  const _LabBody({
    required this.state,
    required this.busy,
    required this.error,
    required this.titleController,
    required this.onOnlineChanged,
    required this.onAccountSelected,
    required this.onCreateOffline,
    required this.onRestart,
    required this.onReconnect,
    required this.onDependentUpdate,
    required this.onFailNextRequest,
    required this.onReplay,
    required this.onRepair,
  });

  final OfflineSyncLabSnapshot state;
  final bool busy;
  final Object? error;
  final TextEditingController titleController;
  final ValueChanged<bool> onOnlineChanged;
  final ValueChanged<String> onAccountSelected;
  final VoidCallback onCreateOffline;
  final VoidCallback onRestart;
  final VoidCallback onReconnect;
  final VoidCallback onDependentUpdate;
  final VoidCallback onFailNextRequest;
  final VoidCallback onReplay;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
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
          state: state,
          busy: busy,
          onOnlineChanged: onOnlineChanged,
          onAccountSelected: onAccountSelected,
        ),
        QueueCard(state: state),
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
                  FilledButton.icon(
                    onPressed: busy ? null : onCreateOffline,
                    icon: const Icon(Icons.cloud_off),
                    label: const Text('Create offline'),
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
              OutlinedButton.icon(
                onPressed: busy ? null : onDependentUpdate,
                icon: const Icon(Icons.account_tree),
                label: const Text('Dependent update'),
              ),
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
        NotesCard(notes: state.notes),
        ActivityCard(events: state.events),
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
