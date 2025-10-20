import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';

class OfflineQueueTodosPage extends StatefulWidget {
  const OfflineQueueTodosPage({super.key});

  @override
  State<OfflineQueueTodosPage> createState() => _OfflineQueueTodosPageState();
}

class _OfflineQueueTodosPageState extends State<OfflineQueueTodosPage> {
  final Mutation<String, String> _addTodoMutation = Mutation<String, String>(
    mutationFn: (String todo) async {
      await Future.delayed(const Duration(milliseconds: 500));
      return 'Added: $todo';
    },
    options: const MutationOptions(
      queueWhenOffline: true,
      maxRetries: 3,
      priority: 1, // Low priority for todos
    ),
  );

  final TextEditingController _todoController = TextEditingController();
  bool _isOffline = false;
  List<String> _todos = [];

  @override
  void initState() {
    super.initState();
    _registerMutationTypes();
    _addTodoMutation.stream.listen((state) {
      if (state.isSuccess) {
        setState(() {
          _todos.add(state.data!);
        });
        _todoController.clear();
      }
    });
  }

  void _registerMutationTypes() {
    // Register the todo mutation type for offline processing
    MutationTypeRegistry.register<String, String>(
      'addTodo',
      (String todo) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return 'Processed: $todo';
      },
    );
  }

  @override
  void dispose() {
    _todoController.dispose();
    _addTodoMutation.dispose();
    super.dispose();
  }

  void _toggleOffline() {
    setState(() {
      _isOffline = !_isOffline;
    });
    NetworkStatus.instance.setOnline(!_isOffline);

    // Process queue when coming back online
    if (!_isOffline) {
      _processQueue();
    }
  }

  void _processQueue() async {
    final queueManager = OfflineQueueManager.instance;
    if (queueManager.length > 0) {
      await queueManager.processQueue();
      _refreshTodos();
    }
  }

  void _refreshTodos() {
    setState(() {});
  }

  void _addTodo() {
    final todo = _todoController.text.trim();
    if (todo.isEmpty) return;

    _addTodoMutation.mutate(todo);
  }

  @override
  Widget build(BuildContext context) {
    final queueStats = OfflineQueueManager.instance.getQueueStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Queue Todos'),
        actions: [
          StreamBuilder<List<OfflineMutationEntry>>(
            stream: OfflineQueueManager.instance.stream,
            builder: (context, snapshot) {
              final queueLength = snapshot.data?.length ?? 0;
              if (queueLength > 0) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Badge(
                    label: Text('$queueLength'),
                    child: const Icon(Icons.queue),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Switch(
            value: _isOffline,
            onChanged: (_) => _toggleOffline(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: _isOffline ? Colors.red.shade100 : Colors.green.shade100,
            child: Row(
              children: [
                Icon(
                  _isOffline ? Icons.wifi_off : Icons.wifi,
                  color: _isOffline ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOffline ? 'Offline Mode' : 'Online Mode',
                  style: TextStyle(
                    color: _isOffline ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Queue Statistics
          if (queueStats.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Queue Statistics:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...queueStats.entries.map((entry) {
                    return Text('${entry.key}: ${entry.value} pending');
                  }),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _todoController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a todo...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<MutationState<String>>(
                  stream: _addTodoMutation.stream,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? _addTodoMutation.state;
                    return ElevatedButton(
                      onPressed: state.isLoading ? null : _addTodo,
                      child: state.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add'),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // Queue Details Section
                if (OfflineQueueManager.instance.length > 0)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Queued Mutations:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...OfflineQueueManager.instance.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.queue,
                                    size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${entry.variables}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  'Priority: ${entry.priority}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Attempts: ${entry.attempts}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // Todo List
                Expanded(
                  child: ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(_todos[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
