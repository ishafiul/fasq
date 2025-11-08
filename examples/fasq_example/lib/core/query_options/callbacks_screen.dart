import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../query_keys.dart';

class CallbacksScreen extends StatefulWidget {
  const CallbacksScreen({super.key});

  @override
  State<CallbacksScreen> createState() => _CallbacksScreenState();
}

class _CallbacksScreenState extends State<CallbacksScreen> {
  final List<String> _callbackLog = [];
  int _successCount = 0;
  int _errorCount = 0;
  bool _simulateError = false;

  void _addLog(String message, Color color) {
    if (mounted) {
      setState(() {
        _callbackLog.insert(0, message);
        // Keep only last 50 log entries
        if (_callbackLog.length > 50) {
          _callbackLog.removeAt(_callbackLog.length - 1);
        }
      });

      // Show snackbar for important events
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Query Callbacks',
      description:
          'Demonstrates onSuccess and onError callbacks that execute when queries complete or fail. Use callbacks for analytics, logging, notifications, and user feedback.',
      codeSnippet: '''
QueryBuilder<List<User>>(
  queryKey: QueryKeys.usersCallbacksDemo,
  queryFn: () => ApiService.fetchUsers(),
  options: QueryOptions(
    onSuccess: () {
      // Called when query succeeds
      print('Users loaded successfully!');
      analytics.track('users_fetched');
      showNotification('New users available');
    },
    onError: (error) {
      // Called when query fails
      print('Failed to load users: \$error');
      analytics.track('users_fetch_failed');
      showError('Failed to load users');
    },
  ),
  builder: (context, state) {
    // Your UI here
  },
)

// Callbacks are perfect for:
// - Analytics tracking
// - Error logging
// - User notifications
// - Cache invalidation
// - Dependent queries
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          _buildControls(),
          const SizedBox(height: 16),
          Expanded(
            child: QueryBuilder<List<User>>(
              queryKey: QueryKeys.usersCallbacksDemo,
              queryFn: () => _fetchUsers(),
              options: QueryOptions(
                onSuccess: () {
                  _successCount++;
                  _addLog(
                    '✅ onSuccess called: Users fetched successfully',
                    Colors.green,
                  );
                },
                onError: (error) {
                  _errorCount++;
                  _addLog(
                    '❌ onError called: ${error.toString()}',
                    Colors.red,
                  );
                },
              ),
              builder: (context, state) {
                if (state.isLoading && !state.hasData) {
                  return const LoadingWidget(message: 'Fetching users...');
                }

                if (state.hasError) {
                  return CustomErrorWidget(
                    message: state.error.toString(),
                    onRetry: () {
                      QueryClient()
                          .getQueryByKey<List<User>>(
                              QueryKeys.usersCallbacksDemo)
                          ?.fetch();
                    },
                  );
                }

                if (state.hasData) {
                  return Column(
                    children: [
                      _buildStats(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildCallbackLog(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildUserList(state),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return const EmptyWidget(message: 'No users found');
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
                Icons.call_made,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'How callbacks work:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1️⃣ Watch the callback log - events appear in real-time\n'
            '2️⃣ Successful fetches trigger onSuccess callback\n'
            '3️⃣ Failed fetches trigger onError callback\n'
            '4️⃣ Toggle "Simulate Error" to see onError in action\n'
            '5️⃣ Use callbacks for analytics, logging, and notifications\n'
            '6️⃣ Track success/error counts for debugging',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Success Count',
              _successCount.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Error Count',
              _errorCount.toString(),
              Icons.error,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCallbackLog() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Callback Log',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _callbackLog.isEmpty
                ? Center(
                    child: Text(
                      'No callbacks yet...\nFetch data to see events',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _callbackLog.length,
                    itemBuilder: (context, index) {
                      final log = _callbackLog[index];
                      final isError = log.contains('❌');
                      final isSuccess = log.contains('✅');

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isError
                              ? Colors.red.withOpacity(0.1)
                              : isSuccess
                                  ? Colors.green.withOpacity(0.1)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isError
                                  ? Icons.error_outline
                                  : isSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                              size: 16,
                              color: isError
                                  ? Colors.red
                                  : isSuccess
                                      ? Colors.green
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
            'Test Callbacks',
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
                      'Simulate Error',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _simulateError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(
                      _simulateError
                          ? 'Next fetch will trigger onError'
                          : 'Next fetch will trigger onSuccess',
                    ),
                    value: _simulateError,
                    onChanged: (value) {
                      setState(() {
                        _simulateError = value;
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
                    QueryClient()
                        .getQueryByKey<List<User>>(QueryKeys.usersCallbacksDemo)
                        ?.fetch();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Fetch Users'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _callbackLog.clear();
                      _successCount = 0;
                      _errorCount = 0;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Log cleared'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Log'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(QueryState<List<User>> state) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Users (${state.data!.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: state.data!.length,
              itemBuilder: (context, index) {
                final user = state.data![index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(user.name[0]),
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: Text(
                      '${user.id}',
                      style: Theme.of(context).textTheme.bodySmall,
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

  Future<List<User>> _fetchUsers() async {
    if (_simulateError) {
      throw Exception('Simulated error for callbacks demo');
    }
    final users = await ApiService.fetchUsers();
    return users;
  }
}
