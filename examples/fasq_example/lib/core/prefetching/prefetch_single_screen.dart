import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../../widgets/example_scaffold.dart';

class PrefetchSingleScreen extends StatelessWidget {
  const PrefetchSingleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrefetchSingleContent();
  }
}

class _PrefetchSingleContent extends StatefulWidget {
  const _PrefetchSingleContent();

  @override
  State<_PrefetchSingleContent> createState() => _PrefetchSingleContentState();
}

class _PrefetchSingleContentState extends State<_PrefetchSingleContent> {
  final List<String> _eventLog = [];
  bool _isPrefetching = false;
  DateTime? _prefetchStartTime;
  DateTime? _prefetchEndTime;

  void _addLog(String message) {
    setState(() {
      _eventLog.insert(0,
          '${DateTime.now().toLocal().toString().substring(11, 19)} $message');
      if (_eventLog.length > 20) {
        _eventLog.removeLast();
      }
    });
  }

  Future<void> _prefetchUsers() async {
    if (_isPrefetching) return;

    final queryClient = context.queryClient;
    if (queryClient == null) {
      _addLog('❌ QueryClient not found');
      return;
    }

    setState(() {
      _isPrefetching = true;
      _prefetchStartTime = DateTime.now();
    });

    _addLog('🚀 Starting prefetch of users...');

    try {
      await queryClient.prefetchQuery<List<User>>(
        'prefetch-users',
        () => ApiService.fetchUsers(),
      );

      final duration = DateTime.now().difference(_prefetchStartTime!);
      _prefetchEndTime = DateTime.now();

      setState(() {
        _isPrefetching = false;
      });

      _addLog('✅ Prefetch completed in ${duration.inMilliseconds}ms');
      _addLog('💾 Users data cached successfully');
      _addLog('✨ Navigate to Users Page to see instant loading!');
      _updateCacheStatus();
    } catch (e) {
      setState(() {
        _isPrefetching = false;
      });
      _addLog('❌ Prefetch error: $e');
    }
  }

  void _clearPrefetchedData() {
    final queryClient = context.queryClient;
    if (queryClient == null) return;

    queryClient.cache.remove('prefetch-users');
    _addLog('🗑️ Cleared prefetched data');
    _updateCacheStatus();
  }

  void _updateCacheStatus() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Prefetch Single',
      description:
          'Demonstrates prefetching a single query to warm the cache. Prefetch users data, then navigate to the Users Page to see instant loading from cache.',
      codeSnippet: '''
await queryClient.prefetchQuery<List<User>>(
  'users',
  () => api.fetchUsers(),
);

// Navigate to a page that uses this query
// It will load instantly from cache!
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
                  _buildCacheStatus(),
                  const SizedBox(height: 16),
                  _buildActions(),
                  const SizedBox(height: 16),
                  _buildNavigationButton(),
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
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Single Query Prefetching:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Prefetch a single query to warm the cache. After prefetching, navigate to the Users Page to see instant loading from cache - no network requests! Perfect for predictive loading on user interaction.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCacheStatus() {
    final queryClient = context.queryClient;
    if (queryClient == null) {
      return const SizedBox.shrink();
    }

    final info = queryClient.cache.getCacheInfo();
    final keys = queryClient.cache.getCacheKeys();
    final hasPrefetched = keys.contains('prefetch-users');

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
            'Cache Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildStatRow('Total Entries', '${info.entryCount}'),
          _buildStatRow(
            'Prefetched Query',
            hasPrefetched ? '✅ Users' : '❌ None',
          ),
          if (_prefetchStartTime != null && _prefetchEndTime != null) ...[
            _buildStatRow(
              'Last Prefetch Duration',
              '${_prefetchEndTime!.difference(_prefetchStartTime!).inMilliseconds}ms',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isPrefetching ? null : _prefetchUsers,
          icon: _isPrefetching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download),
          label: Text(_isPrefetching ? 'Prefetching...' : 'Prefetch Users'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _clearPrefetchedData,
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear Cache'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButton() {
    final queryClient = context.queryClient;
    if (queryClient == null) {
      return const SizedBox.shrink();
    }

    final keys = queryClient.cache.getCacheKeys();
    final hasPrefetched = keys.contains('prefetch-users');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Navigate to Page',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          hasPrefetched
              ? 'Data is prefetched! Navigate to see instant loading from cache.'
              : 'Prefetch data first, then navigate to see instant loading.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasPrefetched
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: hasPrefetched ? FontWeight.bold : FontWeight.normal,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.people, color: Colors.blue),
            title: const Text('Users Page'),
            subtitle: Text(
              hasPrefetched
                  ? '✅ Prefetched - will load instantly'
                  : '❌ Not prefetched - will fetch from network',
              style: TextStyle(
                fontSize: 12,
                color: hasPrefetched
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const _UsersPage(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Log',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: _eventLog.isEmpty
              ? Center(
                  child: Text(
                    'No events yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _eventLog.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _eventLog[index],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _UsersPage extends StatefulWidget {
  const _UsersPage();

  @override
  State<_UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<_UsersPage> {
  Query<List<User>>? _usersQuery;
  QueryState<List<User>>? _state;
  DateTime? _loadStartTime;
  bool _loadedFromCache = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadStartTime = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final queryClient = context.queryClient;
    if (queryClient == null) {
      return;
    }

    _initialized = true;

    final hasCache =
        queryClient.cache.getCacheKeys().contains('prefetch-users');

    _usersQuery = queryClient.getQuery<List<User>>(
      'prefetch-users',
      () => ApiService.fetchUsers(),
    );

    _state = _usersQuery!.state;
    _loadedFromCache = hasCache && _state?.hasData == true;

    _usersQuery!.stream.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
        });
      }
    });

    if (!_loadedFromCache) {
      _usersQuery!.fetch();
    }
  }

  @override
  void dispose() {
    _usersQuery?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Page'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _loadedFromCache
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _loadedFromCache ? Icons.flash_on : Icons.cloud_download,
                      color: _loadedFromCache ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _loadedFromCache
                          ? '✅ Loaded from cache (instant)'
                          : '🔄 Fetching from network...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _loadedFromCache ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                if (_state != null && _state!.hasData && _loadStartTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Load time: ${DateTime.now().difference(_loadStartTime!).inMilliseconds}ms',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _usersQuery == null || _state == null
                ? const Center(child: CircularProgressIndicator())
                : _state!.isLoading && !_state!.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : _state!.hasError
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text('Error: ${_state!.error}'),
                              ],
                            ),
                          )
                        : _state!.hasData
                            ? ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _state!.data!.length,
                                itemBuilder: (context, index) {
                                  final user = _state!.data![index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text(user.name[0]),
                                      ),
                                      title: Text(user.name),
                                      subtitle: Text(user.email),
                                    ),
                                  );
                                },
                              )
                            : const Center(child: Text('No data')),
          ),
        ],
      ),
    );
  }
}
