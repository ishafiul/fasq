import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

import '../../services/models.dart';
import '../../widgets/example_scaffold.dart';
import 'offline_mutations.dart';

class OfflineMutationScreen extends StatefulWidget {
  const OfflineMutationScreen({super.key});

  @override
  State<OfflineMutationScreen> createState() => _OfflineMutationScreenState();
}

class _OfflineMutationScreenState extends State<OfflineMutationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final List<String> _eventLog = <String>[];
  StreamSubscription<bool>? _networkSubscription;
  var _isOffline = false;

  @override
  void initState() {
    super.initState();
    _isOffline = !NetworkStatus.instance.isOnline;
    _networkSubscription = NetworkStatus.instance.stream.listen(
      _onNetworkChanged,
    );
  }

  void _onNetworkChanged(bool isOnline) {
    if (!mounted) return;
    setState(() {
      _isOffline = !isOnline;
      _eventLog.insert(
        0,
        isOnline ? '📡 Network came ONLINE' : '📡 Network went OFFLINE',
      );
    });
  }

  void _toggleNetwork() {
    NetworkStatus.instance.setOnline(online: _isOffline);
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _eventLog.insert(0, message);
      if (_eventLog.length > 30) _eventLog.removeLast();
    });
  }

  @override
  void dispose() {
    unawaited(_networkSubscription?.cancel());
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Offline Mutations',
      description:
          'Generated durable mutations execute immediately online and are persisted for replay when the network is unavailable.',
      codeSnippet: '''
MutationBuilder<Todo, CreateTodoRequest>(
  mutationKey: createTodoMutationKey,
  builder: (context, state, mutate) {
    return ElevatedButton(
      onPressed: () => mutate(request),
      child: Text(state.isQueued ? 'Saved offline' : 'Create todo'),
    );
  },
)
''',
      child: MutationBuilder<Todo, CreateTodoRequest>(
        mutationKey: createTodoMutationKey,
        options: MutationOptions<Todo, CreateTodoRequest>(
          onSuccess: (todo) {
            _titleController.clear();
            _addLog('✅ Todo created: ${todo.title}');
          },
          onError: (error) => _addLog('❌ Mutation failed: $error'),
          onQueued: (request) =>
              _addLog('📥 Mutation queued: "${request.title}"'),
        ),
        builder: (context, state, mutate) {
          return _buildContent(context, state, mutate);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MutationState<Todo> mutationState,
    Future<MutationSubmission<Todo>> Function(CreateTodoRequest) mutate,
  ) {
    final queue = context.fasqRuntime.mutationQueue;
    return StreamBuilder<DurableQueueObservation>(
      stream: queue?.watch(),
      initialData: queue?.observation,
      builder: (context, snapshot) {
        final observation = snapshot.data;
        return Column(
          children: [
            _buildNetworkStatus(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInstructions(),
                    const SizedBox(height: 16),
                    _buildQueueInfo(observation),
                    const SizedBox(height: 16),
                    _buildMutationForm(mutationState, mutate),
                    const SizedBox(height: 16),
                    _buildEventLog(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNetworkStatus() {
    final color = _isOffline ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isOffline ? Icons.signal_wifi_off : Icons.wifi,
                size: 32,
                color: color,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOffline ? 'Network: OFFLINE' : 'Network: ONLINE',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    _isOffline
                        ? 'Mutations will be queued'
                        : 'Mutations execute immediately',
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _toggleNetwork,
            icon: Icon(_isOffline ? Icons.network_check : Icons.network_locked),
            label: Text(_isOffline ? 'Go Online' : 'Go Offline'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOffline ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueInfo(DurableQueueObservation? observation) {
    final queueState = observation?.aggregateState.name ?? 'idle';
    final operationCount = observation?.operations.length ?? 0;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Queue Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Pending operations', '$operationCount', Icons.queue),
          _buildInfoRow('Aggregate state', queueState, Icons.sync),
          _buildInfoRow(
            'Network status',
            _isOffline ? 'Offline - Queuing' : 'Online - Ready',
            Icons.network_check,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          SizedBox(width: 140, child: Text('$label:')),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return _panel(
      child: const Text(
        '1️⃣ Switch the network OFFLINE.\n'
        '2️⃣ Create a todo; Fasq persists it in the durable outbox.\n'
        '3️⃣ Switch ONLINE; lifecycle replay executes the queued mutation.\n'
        '4️⃣ Inspect queue state and the event log.',
      ),
    );
  }

  Widget _buildMutationForm(
    MutationState<Todo> state,
    Future<MutationSubmission<Todo>> Function(CreateTodoRequest) mutate,
  ) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Todo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Todo Title',
              hintText: 'Enter todo title...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.task),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a title'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      unawaited(
                        mutate(CreateTodoRequest(userId: 1, title: title)),
                      );
                    },
              icon: Icon(state.isLoading ? Icons.hourglass_empty : Icons.add),
              label: Text(state.isLoading ? 'Creating...' : 'Create Todo'),
            ),
          ),
          if (state.isQueued) ...[
            const SizedBox(height: 16),
            const Text('Mutation queued - it will replay when online.'),
          ],
        ],
      ),
    );
  }

  Widget _buildEventLog() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Log',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_eventLog.isEmpty)
            const Text('No events yet.')
          else
            ..._eventLog.map(Text.new),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
