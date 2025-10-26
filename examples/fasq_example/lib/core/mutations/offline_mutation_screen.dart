import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/models.dart';

class OfflineMutationScreen extends StatefulWidget {
  const OfflineMutationScreen({super.key});

  @override
  State<OfflineMutationScreen> createState() => _OfflineMutationScreenState();
}

class _OfflineMutationScreenState extends State<OfflineMutationScreen> {
  final TextEditingController _titleController = TextEditingController();
  late Mutation<Todo, CreateTodoRequest> _mutation;
  StreamSubscription? _subscription;
  final List<String> _eventLog = [];
  bool _isOffline = false;
  int _queuedMutations = 0;
  Timer? _networkTimer;
  bool _isExecutingQueued = false;

  @override
  void initState() {
    super.initState();
    _initializeMutation();
    _setupQueueExecutionListener();
  }

  void _setupQueueExecutionListener() {
    // Periodically check if we should execute queued mutations
    _networkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // If we go from offline to online and have queued mutations, execute them
      if (!_isOffline && _queuedMutations > 0 && !_isExecutingQueued) {
        setState(() {
          _isExecutingQueued = true;
          _addLog('🔄 Executing queued mutations...');
        });
        
        // Execute queued mutations
        _executeQueuedMutations();
      }
    });
  }

  void _toggleNetwork() {
    final wasOffline = _isOffline;
    
    setState(() {
      _isOffline = !_isOffline;
      _addLog(_isOffline 
          ? '📡 Network toggled OFFLINE' 
          : '📡 Network toggled ONLINE');
    });
    
    // If we went online and have queued mutations, execute them
    if (!_isOffline && wasOffline && _queuedMutations > 0) {
      setState(() {
        _isExecutingQueued = true;
        _addLog('🔄 Executing queued mutations...');
      });
      
      Future.delayed(const Duration(milliseconds: 300), () {
        _executeQueuedMutations();
      });
    }
  }

  void _executeQueuedMutations() {
    // Simulate executing queued mutations
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _queuedMutations > 0) {
        setState(() {
          final executedCount = _queuedMutations;
          _queuedMutations = 0;
          _isExecutingQueued = false;
          _addLog('✅ Executed $executedCount queued mutation(s)');
        });
      }
    });
  }

  void _initializeMutation() {
    _mutation = Mutation<Todo, CreateTodoRequest>(
      mutationFn: (request) async {
        if (_isOffline) {
          throw Exception('Network is offline - mutation will be queued');
        }

        // Simulate network delay
        await Future.delayed(const Duration(milliseconds: 500));

        // Return a mock todo
        return Todo(
          id: DateTime.now().millisecondsSinceEpoch,
          userId: request.userId,
          title: request.title,
          completed: request.completed,
        );
      },
      options: MutationOptions<Todo, CreateTodoRequest>(
        onSuccess: (data) {
          if (mounted) {
            _addLog('✅ Mutation succeeded: ${data.title}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Todo created: ${data.title}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _titleController.clear();
          }
        },
        onError: (error) {
          if (mounted) {
            _addLog('❌ Mutation failed: ${error.toString()}');
          }
        },
        onMutate: (data, variables) {
          if (mounted) {
            _addLog('🔄 Mutation started with title: ${variables.title}');
          }
        },
        queueWhenOffline: true, // Enable offline queue
        onQueued: (variables) {
          if (mounted) {
            _queuedMutations++;
            _addLog('📥 Mutation queued (total queued: $_queuedMutations)');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.queue, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mutation queued - will execute when online ($_queuedMutations in queue)',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );

    _subscription = _mutation.stream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _eventLog.insert(0, message);
        if (_eventLog.length > 30) {
          _eventLog.removeLast();
        }
      });
    }
  }

  @override
  void dispose() {
    _networkTimer?.cancel();
    _subscription?.cancel();
    _mutation.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Offline Mutations',
      description:
          'Demonstrates offline mutation queuing. Mutations are queued when network is offline and automatically executed when connection is restored. Perfect for offline-first apps.',
      codeSnippet: '''
MutationOptions<Todo, CreateTodoRequest>(
  queueWhenOffline: true, // Enable offline queue
  
  // Called when mutation is queued
  onQueued: (variables) {
    print('Mutation queued: \${variables.title}');
    showQueuedNotification();
  },
  
  // Called when mutation succeeds
  onSuccess: (data) {
    print('Mutation succeeded after going online');
  },
  
  // Called on error
  onError: (error) {
    print('Mutation failed: \$error');
  },
)

// Behavior:
// - Works normally when online
// - Queues mutations when offline
// - Automatically retries when online
// - Shows queue status to user
''',
      child: Column(
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
                  _buildQueueInfo(),
                  const SizedBox(height: 16),
                  _buildMutationForm(),
                  const SizedBox(height: 16),
                  _buildEventLog(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isOffline
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        border: Border.all(
          color: _isOffline ? Colors.red : Colors.green,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isOffline ? Icons.signal_wifi_off : Icons.wifi,
                size: 32,
                color: _isOffline ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOffline ? 'Network: OFFLINE' : 'Network: ONLINE',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isOffline ? Colors.red : Colors.green,
                        ),
                  ),
                  Text(
                    _isOffline
                        ? 'Mutations will be queued'
                        : 'Mutations execute immediately',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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

  Widget _buildQueueInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.queue,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Queue Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Queued Mutations',
            '$_queuedMutations',
            Icons.queue,
          ),
          _buildInfoRow(
            'Execution Status',
            _isExecutingQueued 
                ? '🔄 Executing...'
                : _queuedMutations > 0
                    ? '⏸️ Waiting for online'
                    : '✅ All processed',
            _isExecutingQueued 
                ? Icons.sync
                : _queuedMutations > 0
                    ? Icons.pause_circle
                    : Icons.check_circle,
          ),
          _buildInfoRow(
            'Network Status',
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
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'How offline mutations work:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1️⃣ Use the toggle button to switch between ONLINE/OFFLINE\n'
            '2️⃣ Create a todo when ONLINE - executes immediately\n'
            '3️⃣ Toggle to OFFLINE, create todos - they get queued\n'
            '4️⃣ Watch queue status: "⏸️ Waiting for online"\n'
            '5️⃣ Toggle back to ONLINE\n'
            '6️⃣ Queued mutations execute automatically\n'
            '7️⃣ Watch "Execution Status" change to "🔄 Executing..." then "✅ All processed"\n'
            '8️⃣ Check Event Log to see the complete flow',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildMutationForm() {
    final state = _mutation.state;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Todo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                      if (_titleController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a title'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final request = CreateTodoRequest(
                        userId: 1,
                        title: _titleController.text,
                        completed: false,
                      );

                      _mutation.mutate(request);
                    },
              icon: Icon(state.isLoading ? Icons.hourglass_empty : Icons.add),
              label: Text(state.isLoading ? 'Creating...' : 'Create Todo'),
            ),
          ),
          if (state.isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (state.isQueued) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.queue, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mutation queued - will execute when online',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventLog() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Event Log',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _eventLog.clear();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _eventLog.isEmpty
                ? Center(
                    child: Text(
                      'Events will appear here...\nCreate todos to see mutations in action',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _eventLog.length,
                    itemBuilder: (context, index) {
                      final log = _eventLog[index];
                      final isError = log.contains('❌');
                      final isSuccess = log.contains('✅');
                      final isQueued = log.contains('📥');
                      final isNetwork = log.contains('📡');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isError
                              ? Colors.red.withOpacity(0.1)
                              : isSuccess
                                  ? Colors.green.withOpacity(0.1)
                                  : isQueued
                                      ? Colors.orange.withOpacity(0.1)
                                      : isNetwork
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isError
                                  ? Icons.error_outline
                                  : isSuccess
                                      ? Icons.check_circle_outline
                                      : isQueued
                                          ? Icons.queue_outlined
                                          : isNetwork
                                              ? Icons
                                                  .signal_cellular_alt_outlined
                                              : Icons.info_outline,
                              size: 16,
                              color: isError
                                  ? Colors.red
                                  : isSuccess
                                      ? Colors.green
                                      : isQueued
                                          ? Colors.orange
                                          : isNetwork
                                              ? Colors.blue
                                              : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
