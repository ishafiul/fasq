import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class RefetchOnMountScreen extends StatefulWidget {
  const RefetchOnMountScreen({super.key});

  @override
  State<RefetchOnMountScreen> createState() => _RefetchOnMountScreenState();
}

class _RefetchOnMountScreenState extends State<RefetchOnMountScreen> {
  bool _refetchOnMount = false;
  int _mountCount = 0;
  DateTime? _lastFetchTime;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _mountCount++;
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Refetch On Mount',
      description:
          'Demonstrates how refetchOnMount forces fresh data fetch every time the component mounts, even if cached data is available. Useful for ensuring data freshness on navigation.',
      codeSnippet: '''
QueryBuilder<List<Todo>>(
  queryKey: 'todos-refetch-on-mount-demo',
  queryFn: () => ApiService.fetchTodos(),
  options: QueryOptions(
    refetchOnMount: true, // Always refetch when component mounts
    staleTime: Duration(seconds: 60), // Data is fresh for 1 minute
  ),
  builder: (context, state) {
    if (state.isLoading && !state.hasData) {
      return LoadingWidget(message: 'Fetching fresh data...');
    }
    
    if (state.hasData) {
      return TodoList(todos: state.data!);
    }
    
    return EmptyWidget(message: 'No todos found');
  },
)

// Key difference:
// - Normal behavior: Uses cached data on remount
// - With refetchOnMount: Always makes network request
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          _buildControls(),
          const SizedBox(height: 16),
          Expanded(
            child: QueryBuilder<List<Todo>>(
              queryKey: 'todos-refetch-on-mount-demo',
              queryFn: () => _fetchTodos(),
              options: QueryOptions(
                refetchOnMount: _refetchOnMount,
                staleTime: const Duration(seconds: 10),
                onSuccess: () {
                  if (mounted) {
                    setState(() {
                      _lastFetchTime = DateTime.now();
                      _mountCount++;
                    });
                  }
                },
              ),
              builder: (context, state) {
                // Update status message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      if (state.isLoading && !state.hasData) {
                        _statusMessage = _refetchOnMount
                            ? '🔄 Refetching on mount... Making network request'
                            : '🔄 Loading... Initial fetch';
                      } else if (state.hasData) {
                        _statusMessage = _refetchOnMount
                            ? '✅ Fresh data loaded from network (refetchOnMount: true)'
                            : '✅ Cached data loaded (refetchOnMount: false)';
                      } else if (state.hasError) {
                        _statusMessage = '❌ Error: ${state.error}';
                      }
                    });
                  }
                });

                if (state.isLoading && !state.hasData) {
                  return const LoadingWidget(message: 'Fetching todos...');
                }

                if (state.hasError) {
                  return CustomErrorWidget(
                    message: state.error.toString(),
                    onRetry: () {
                      QueryClient()
                          .getQueryByKey<List<Todo>>(
                              'todos-refetch-on-mount-demo')
                          ?.fetch();
                    },
                  );
                }

                if (state.hasData) {
                  return Column(
                    children: [
                      _buildStatusIndicator(state),
                      const SizedBox(height: 16),
                      Expanded(child: _buildTodoList(state)),
                    ],
                  );
                }

                return const EmptyWidget(message: 'No todos found');
              },
            ),
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
                Icons.autorenew,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'How to see the effect:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1️⃣ Toggle "Refetch On Mount" switch to enable/disable\n'
            '2️⃣ Navigate away using "Go to Other Screen" button\n'
            '3️⃣ Navigate back - Watch what happens:\n'
            '   • OFF: Uses cached data (instant, no loading)\n'
            '   • ON: Fetches fresh data (loading spinner)\n'
            '4️⃣ Compare the behavior side-by-side\n'
            '5️⃣ Use refetchOnMount for critical/real-time data',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(QueryState<List<Todo>> state) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _refetchOnMount
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _refetchOnMount
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage.isEmpty ? 'Status: Ready' : _statusMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          if (state.isFetching)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
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
            'Configuration',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  child: SwitchListTile(
                    title: Text(
                      'Refetch On Mount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _refetchOnMount
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(
                      _refetchOnMount
                          ? 'Always fetch fresh data on mount'
                          : 'Use cached data if available',
                    ),
                    value: _refetchOnMount,
                    onChanged: (value) {
                      setState(() {
                        _refetchOnMount = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _OtherScreenDemo(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Go to Other Screen'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    QueryClient()
                        .invalidateQuery('todos-refetch-on-mount-demo');
                    setState(() {
                      _mountCount = 0;
                      _lastFetchTime = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.refresh, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Query invalidated - next mount will fetch fresh data',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Invalidate'),
                ),
              ),
            ],
          ),
          if (_lastFetchTime != null) ...[
            const SizedBox(height: 12),
            _buildFetchInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildFetchInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mount Count: $_mountCount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Last Fetch: ${_lastFetchTime!.hour}:${_lastFetchTime!.minute.toString().padLeft(2, '0')}:${_lastFetchTime!.second.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList(QueryState<List<Todo>> state) {
    final completedCount = state.data!.where((todo) => todo.completed).length;
    final totalCount = state.data!.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.task_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Progress: $completedCount / $totalCount completed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.data!.length,
            itemBuilder: (context, index) {
              final todo = state.data![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: todo.completed
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    child: Icon(
                      todo.completed ? Icons.check : Icons.pending,
                      color: todo.completed
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.outlineVariant,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      fontWeight:
                          todo.completed ? FontWeight.normal : FontWeight.bold,
                      color: todo.completed
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'User ${todo.userId} • ID: ${todo.id}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Chip(
                    label: Text(
                      todo.completed ? 'Done' : 'Pending',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: todo.completed
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Todo>> _fetchTodos() async {
    final todos = await ApiService.fetchTodos();
    return todos;
  }
}

class _OtherScreenDemo extends StatelessWidget {
  const _OtherScreenDemo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Other Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.screen_rotation,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'You\'re on a different screen!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Navigate back to see the refetch behavior',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'What to observe:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, Icons.compare_arrows,
                      'Compare loading behavior'),
                  const SizedBox(height: 8),
                  _buildInfoRow(context, Icons.cached,
                      'Cached data (refetchOnMount: false)'),
                  const SizedBox(height: 8),
                  _buildInfoRow(context, Icons.refresh,
                      'Fresh data (refetchOnMount: true)'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back & Observe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ),
      ],
    );
  }
}
