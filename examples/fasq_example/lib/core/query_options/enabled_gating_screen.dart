import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../query_keys.dart';

class EnabledGatingScreen extends StatefulWidget {
  const EnabledGatingScreen({super.key});

  @override
  State<EnabledGatingScreen> createState() => _EnabledGatingScreenState();
}

class _EnabledGatingScreenState extends State<EnabledGatingScreen> {
  bool _queryEnabled = true; // Start enabled for immediate demonstration
  String _statusMessage = '';
  DateTime? _lastFetchTime;

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Enabled Gating',
      description:
          'Demonstrates how the enabled option prevents queries from executing. Useful for conditional fetching based on user authentication, feature flags, or other conditions.',
      codeSnippet: '''
// Query is disabled by default
QueryBuilder<List<User>>(
  queryKey: QueryKeys.usersEnabledDemo,
  queryFn: () => ApiService.fetchUsers(),
  options: QueryOptions(
    enabled: false, // Query won't execute until enabled
  ),
  builder: (context, state) {
    if (!state.isIdle) {
      return LoadingOrDataWidget(state);
    }
    
    // Query hasn't started yet (enabled: false)
    return MessageWidget('Enable the query to start fetching');
  },
)

// Toggle enabled to start/stop query execution
setState(() {
  enabled = !enabled;
});
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          _buildControls(),
          const SizedBox(height: 16),
          Expanded(
            child: QueryBuilder<List<User>>(
              queryKey: QueryKeys.usersEnabledDemo,
              queryFn: () => _fetchUsers(),
              options: QueryOptions(
                enabled: _queryEnabled,
                onSuccess: () {
                  setState(() {
                    _lastFetchTime = DateTime.now();
                  });
                },
              ),
              builder: (context, state) {
                // Update status message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      if (!_queryEnabled) {
                        _statusMessage = '🚫 Query Disabled';
                      } else if (state.isIdle) {
                        _statusMessage = '⏸️  Query Enabled (waiting to start)';
                      } else if (state.isLoading) {
                        _statusMessage = '🔄 Loading... Fetching users';
                      } else if (state.hasData) {
                        _statusMessage =
                            '✅ Data loaded (${state.data!.length} users)';
                      } else if (state.hasError) {
                        _statusMessage = '❌ Error: ${state.error}';
                      }
                    });
                  }
                });

                if (!_queryEnabled) {
                  return _buildDisabledState();
                }

                if (state.isLoading && !state.hasData) {
                  return const LoadingWidget(message: 'Fetching users...');
                }

                if (state.hasError) {
                  return CustomErrorWidget(
                    message: state.error.toString(),
                    onRetry: () {
                      setState(() {
                        _queryEnabled = true;
                      });
                      QueryClient()
                          .getQueryByKey<List<User>>(QueryKeys.usersEnabledDemo)
                          ?.fetch();
                    },
                  );
                }

                if (state.hasData) {
                  return Column(
                    children: [
                      _buildStatusIndicator(state),
                      const SizedBox(height: 16),
                      Expanded(child: _buildUserList(state)),
                    ],
                  );
                }

                return _buildDisabledState();
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
                Icons.toggle_off,
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
            '1️⃣ Start with query DISABLED - No network request will be made\n'
            '2️⃣ Toggle ENABLE to start the query execution\n'
            '3️⃣ Watch the loading spinner and data appear\n'
            '4️⃣ Toggle DISABLE to stop the query (no new fetches)\n'
            '5️⃣ Toggle ENABLE again to see cached data immediately\n'
            '6️⃣ Use this for auth guards, feature flags, and conditional fetching',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(QueryState<List<User>> state) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
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
          if (state.isFetching && _queryEnabled)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildDisabledState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Query is Disabled',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Toggle the switch to enable query execution',
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
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.check_circle, 'Network requests blocked'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.memory, 'No state updates'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.speed, 'Zero performance impact'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
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
            'Query Toggle',
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
                      _queryEnabled ? 'Query Enabled' : 'Query Disabled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _queryEnabled
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      _queryEnabled
                          ? 'Query will execute and fetch data'
                          : 'Query is blocked (no network requests)',
                    ),
                    value: _queryEnabled,
                    onChanged: (value) {
                      setState(() {
                        _queryEnabled = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_lastFetchTime != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _queryEnabled
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: _queryEnabled
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Fetch: ${_lastFetchTime!.hour}:${_lastFetchTime!.minute.toString().padLeft(2, '0')}:${_lastFetchTime!.second.toString().padLeft(2, '0')}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _queryEnabled
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                        ),
                        Text(
                          'Status: ${_queryEnabled ? "Enabled - Fetching allowed" : "Disabled - Fetching blocked"}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _queryEnabled
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                        ),
                      ],
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

  Widget _buildUserList(QueryState<List<User>> state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.data!.length,
      itemBuilder: (context, index) {
        final user = state.data![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _queryEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              child: Text(
                user.name[0],
                style: TextStyle(
                  color: _queryEnabled
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onError,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(user.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                Text(
                  '@${user.username}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            trailing: Text(
              'ID: ${user.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      },
    );
  }

  Future<List<User>> _fetchUsers() async {
    final users = await ApiService.fetchUsers();
    return users;
  }
}
