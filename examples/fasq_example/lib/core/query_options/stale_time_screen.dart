import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class StaleTimeScreen extends StatefulWidget {
  const StaleTimeScreen({super.key});

  @override
  State<StaleTimeScreen> createState() => _StaleTimeScreenState();
}

class _StaleTimeScreenState extends State<StaleTimeScreen> {
  Duration staleTime = const Duration(seconds: 10);
  DateTime? lastFetchTime;
  bool isRefetching = false;
  bool _wasStale = false;

  // Debug information
  String _queryStateInfo = '';
  String _cacheEntryInfo = '';
  String _existingQueryInfo = '';

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Stale Time',
      description:
          'Demonstrates how stale time controls when data is considered fresh vs stale. Fresh data serves instantly from cache, while stale data triggers background refetch.',
      codeSnippet: '''
QueryBuilder<List<User>>(
  queryKey: 'users-stale-demo',
  queryFn: () => ApiService.fetchUsers(),
  options: QueryOptions(
    staleTime: Duration(seconds: 10), // Fresh for 10 seconds
  ),
  builder: (context, state) {
    // Fresh data: served instantly, no loading
    // Stale data: served instantly + background refetch
    // Missing data: shows loading state
    
    if (state.isLoading) {
      return LoadingWidget(message: 'Loading users...');
    }
    
    if (state.hasError) {
      return CustomErrorWidget(
        message: state.error.toString(),
        onRetry: () => // retry logic
      );
    }
    
    if (state.hasData) {
      return UserList(
        users: state.data!,
        isStale: state.isStale,
        isFetching: state.isFetching,
      );
    }
    
    return const EmptyWidget(message: 'No users found');
  },
)''',
      child: Column(
        children: [
          _buildControls(),
          const SizedBox(height: 16),
          _buildDebugInfo(),
          const SizedBox(height: 16),
          Expanded(
            child: QueryBuilder<List<User>>(
              queryKey: 'users-stale-demo',
              queryFn: () => _fetchUsersWithTimestamp(),
              options: QueryOptions(
                staleTime: staleTime,
                onSuccess: () {
                  setState(() {
                    lastFetchTime = DateTime.now();
                    if (_wasStale) {
                      // Show success snackbar when background refetch completes
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Background refetch completed - data is fresh!',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      });
                    }
                    _wasStale = false;
                  });
                },
              ),
              builder: (context, state) {
                // Capture debug information for UI display
                final client = QueryClient();
                final cacheEntry =
                    client.cache.get<List<User>>('users-stale-demo');
                final existingQuery =
                    client.getQueryByKey<List<User>>('users-stale-demo');

                // Update debug info
                setState(() {
                  _queryStateInfo =
                      'Query State - isLoading: ${state.isLoading}, isStale: ${state.isStale}, isFetching: ${state.isFetching}, hasData: ${state.hasData}';

                  if (cacheEntry != null) {
                    _cacheEntryInfo =
                        'Cache Entry - age: ${cacheEntry.age.inSeconds}s, staleTime: ${cacheEntry.staleTime.inSeconds}s, isFresh: ${cacheEntry.isFresh}, isStale: ${cacheEntry.isStale}';
                  } else {
                    _cacheEntryInfo = 'Cache Entry - not found';
                  }

                  _existingQueryInfo =
                      'Existing Query - ${existingQuery != null ? "found" : "not found"}';
                });

                // Show snackbar when background refetch starts
                if (state.isStale && state.isFetching && !_wasStale) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.refresh, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Background refetch triggered - data is stale!',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  });
                  _wasStale = true;
                }

                // Also show snackbar when stale data is first detected (even if not fetching yet)
                if (state.isStale &&
                    state.hasData &&
                    !_wasStale &&
                    !state.isFetching) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.schedule, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Data is stale - background refetch will start soon',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  });
                  _wasStale = true;
                }

                if (state.isLoading) {
                  return const LoadingWidget(message: 'Loading users...');
                }

                if (state.hasError) {
                  return CustomErrorWidget(
                    message: state.error.toString(),
                    onRetry: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StaleTimeScreen(),
                        ),
                      );
                    },
                  );
                }

                if (state.hasData) {
                  return _buildUserList(state);
                }

                return const EmptyWidget(message: 'No users found');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Debug Information',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDebugRow('Query State', _queryStateInfo),
          const SizedBox(height: 8),
          _buildDebugRow('Cache Entry', _cacheEntryInfo),
          const SizedBox(height: 8),
          _buildDebugRow('Query Client', _existingQueryInfo),
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not available' : value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurface,
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
            'Stale Time Configuration',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stale Time: ${staleTime.inSeconds}s',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Slider(
                      value: staleTime.inSeconds.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 25,
                      onChanged: (value) {
                        setState(() {
                          staleTime = Duration(seconds: value.round());
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      QueryClient().invalidateQuery('users-stale-demo');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.refresh, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Manual refetch triggered',
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
                    label: const Text('Refetch'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      QueryClient().removeQuery('users-stale-demo');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.clear, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cache cleared - next access will fetch fresh data',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.outline,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Cache'),
                  ),
                ],
              ),
            ],
          ),
          if (lastFetchTime != null) ...[
            const SizedBox(height: 12),
            _buildDataAgeIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildDataAgeIndicator() {
    return StreamBuilder<DateTime>(
      stream:
          Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        if (lastFetchTime == null) return const SizedBox.shrink();

        final now = snapshot.data ?? DateTime.now();
        final age = now.difference(lastFetchTime!);
        final isStale = age >= staleTime;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isStale
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isStale ? Icons.schedule : Icons.check_circle,
                color: isStale
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isStale ? 'Data is STALE' : 'Data is FRESH',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isStale
                                ? Theme.of(context).colorScheme.onErrorContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                          ),
                    ),
                    Text(
                      'Age: ${age.inSeconds}s / ${staleTime.inSeconds}s',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isStale
                                ? Theme.of(context).colorScheme.onErrorContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserList(QueryState<List<User>> state) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: state.isStale
                ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
                : Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                state.isStale ? Icons.schedule : Icons.check_circle,
                color: state.isStale
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.isStale
                      ? 'Showing stale data (background refetch ${state.isFetching ? 'in progress' : 'triggered'})'
                      : 'Showing fresh data',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: state.isStale
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
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
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.data!.length,
            itemBuilder: (context, index) {
              final user = state.data![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: state.isStale
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    child: Text(
                      user.name[0],
                      style: TextStyle(
                        color: state.isStale
                            ? Theme.of(context).colorScheme.onError
                            : Theme.of(context).colorScheme.onPrimary,
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
          ),
        ),
      ],
    );
  }

  Future<List<User>> _fetchUsersWithTimestamp() async {
    final users = await ApiService.fetchUsers();
    return users;
  }
}
