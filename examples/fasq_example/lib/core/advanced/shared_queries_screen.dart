import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class SharedQueriesScreen extends StatefulWidget {
  const SharedQueriesScreen({super.key});

  @override
  State<SharedQueriesScreen> createState() => _SharedQueriesScreenState();
}

class _SharedQueriesScreenState extends State<SharedQueriesScreen> {
  late QueryClient _queryClient;
  final List<String> _eventLog = [];
  int _fetchCount = 0;
  int _widgetCount = 0;

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient();
    _addLog('Initialized shared QueryClient');
  }

  void _addLog(String message) {
    setState(() {
      _eventLog.insert(
          0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (_eventLog.length > 20) {
        _eventLog.removeLast();
      }
    });
  }

  void _addWidget() {
    setState(() {
      _widgetCount++;
      _addLog('Added Widget #$_widgetCount');
    });
  }

  void _removeWidget() {
    if (_widgetCount > 0) {
      setState(() {
        _widgetCount--;
        _addLog('Removed Widget #${_widgetCount + 1}');
      });
    }
  }

  void _clearLog() {
    setState(() {
      _eventLog.clear();
      _fetchCount = 0;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Shared Queries',
      description:
          'Demonstrates how multiple widgets share the same query instance and cache. When multiple widgets use the same query key, only one network request is made and all widgets receive the same cached data.',
      codeSnippet: '''
// All widgets share the same QueryClient
final queryClient = QueryClient();

// Widget 1
QueryBuilder<User>(
  key: 'user-1',
  queryFn: () => api.fetchUser(1),
  cache: queryClient.cache,
  builder: (context, state) => Text(state.data?.name ?? 'Loading...'),
)

// Widget 2 - Same query key = shared data
QueryBuilder<User>(
  key: 'user-1', // Same key!
  queryFn: () => api.fetchUser(1),
  cache: queryClient.cache,
  builder: (context, state) => Text(state.data?.name ?? 'Loading...'),
)

// Benefits:
// - Single network request
// - Shared cache state
// - Automatic updates across widgets
// - Reduced API calls
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildControls(),
                  const SizedBox(height: 16),
                  _buildSharedWidgetsList(),
                  const SizedBox(height: 16),
                  _buildStats(),
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
                Icons.share,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Shared Queries Explained:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'When multiple widgets use the same query key:\n'
            '🔗 All widgets share the same query instance\n'
            '🌐 Only ONE network request is made\n'
            '📦 Shared cache state across widgets\n'
            '⚡ Automatic updates when data changes\n'
            '💰 Reduced API calls and bandwidth\n\n'
            'Add/remove widgets above to see the effect!',
            style: Theme.of(context).textTheme.bodySmall,
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
            'Controls',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addWidget,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Widget'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _removeWidget,
                  icon: const Icon(Icons.remove),
                  label: const Text('Remove Widget'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSharedWidgetsList() {
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
            'Shared Widgets ($_widgetCount)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (_widgetCount == 0)
            Center(
              child: Text(
                'No widgets added yet. Click "Add Widget" to start.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            ...List.generate(_widgetCount, (index) {
              return _buildSharedQueryWidget(index);
            }),
        ],
      ),
    );
  }

  Widget _buildSharedQueryWidget(int index) {
    final query = _queryClient.getQuery<User>(
      'shared-user-1',
      () async {
        _fetchCount++;
        _addLog('🌐 Widget #${index + 1} - Network request #$_fetchCount');
        await Future.delayed(const Duration(milliseconds: 1500));
        return ApiService.fetchUser(1);
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: StreamBuilder<QueryState<User>>(
        stream: query.stream,
        initialData: query.state,
        builder: (context, snapshot) {
          final state = snapshot.data!;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Widget #${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (state.isLoading)
                      const Text('Loading...', style: TextStyle(fontSize: 12))
                    else if (state.hasError)
                      Text(
                        'Error: ${state.error}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      )
                    else if (state.hasData)
                      Text(
                        'User: ${state.data!.name}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (state.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (state.hasData)
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                )
              else if (state.hasError)
                Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 20,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStats() {
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
            'Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Widgets', '$_widgetCount'),
              _buildStatItem('Network Requests', '$_fetchCount'),
              _buildStatItem(
                'Efficiency',
                _widgetCount > 0 &&
                        _fetchCount > 0 &&
                        _fetchCount < _widgetCount
                    ? '✅ Optimal'
                    : _widgetCount == 0
                        ? '—'
                        : '⚠️',
              ),
            ],
          ),
          if (_widgetCount > 1 && _fetchCount == 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✅ Perfect! $_widgetCount widgets = $_fetchCount network request',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
                onPressed: _clearLog,
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
                      'Events will appear here...',
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          log,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
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
