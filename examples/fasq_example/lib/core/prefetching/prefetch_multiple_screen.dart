import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import '../query_keys.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../../widgets/example_scaffold.dart';

class PrefetchMultipleScreen extends StatelessWidget {
  const PrefetchMultipleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrefetchMultipleContent();
  }
}

class _PrefetchMultipleContent extends StatefulWidget {
  const _PrefetchMultipleContent();

  @override
  State<_PrefetchMultipleContent> createState() =>
      _PrefetchMultipleContentState();
}

class _PrefetchMultipleContentState extends State<_PrefetchMultipleContent> {
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

  Future<void> _prefetchMultiple() async {
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

    _addLog('🚀 Starting parallel prefetch of 3 queries...');

    try {
      await queryClient.prefetchQueries([
        PrefetchConfig<List<User>>(
          queryKey: QueryKeys.prefetchUsers,
          queryFn: () => ApiService.fetchUsers(),
        ),
        PrefetchConfig<List<Post>>(
          queryKey: QueryKeys.prefetchPosts,
          queryFn: () => ApiService.fetchPosts(),
        ),
        PrefetchConfig<List<Todo>>(
          queryKey: QueryKeys.prefetchTodos,
          queryFn: () => ApiService.fetchTodos(),
        ),
      ]);

      final duration = DateTime.now().difference(_prefetchStartTime!);
      _prefetchEndTime = DateTime.now();

      setState(() {
        _isPrefetching = false;
      });

      _addLog('✅ Prefetch completed in ${duration.inMilliseconds}ms');
      _addLog('💾 All queries cached successfully');
      _addLog('✨ Navigate to any page to see instant loading!');
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

    queryClient.cache.remove(QueryKeys.prefetchUsers.key);
    queryClient.cache.remove(QueryKeys.prefetchPosts.key);
    queryClient.cache.remove(QueryKeys.prefetchTodos.key);
    _addLog('🗑️ Cleared prefetched data');
    _updateCacheStatus();
  }

  void _updateCacheStatus() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Prefetch Multiple',
      description:
          'Demonstrates batch prefetching of multiple queries in parallel. Prefetch queries to warm the cache, then navigate to pages to see instant loading from cache.',
      codeSnippet: '''
await queryClient.prefetchQueries([
  PrefetchConfig(
    key: 'users',
    queryFn: () => api.fetchUsers(),
  ),
  PrefetchConfig(
    key: 'posts',
    queryFn: () => api.fetchPosts(),
  ),
  PrefetchConfig(
    key: 'todos',
    queryFn: () => api.fetchTodos(),
  ),
]);

// Navigate to a page that uses these queries
// They will load instantly from cache!
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
                  _buildNavigationButtons(),
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
                'Batch Prefetching:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Prefetch multiple queries in parallel to warm the cache. '
            'After prefetching, navigate to the Users, Posts, or Todos pages to see '
            'instant loading from cache - no network requests! Perfect for predictive loading.',
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
    final prefetchedKeys =
        keys.where((key) => key.startsWith('prefetch-')).toList();

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
          _buildStatRow('Prefetched Queries', '${prefetchedKeys.length}'),
          if (_prefetchStartTime != null && _prefetchEndTime != null) ...[
            _buildStatRow(
              'Last Prefetch Duration',
              '${_prefetchEndTime!.difference(_prefetchStartTime!).inMilliseconds}ms',
            ),
          ],
          if (prefetchedKeys.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Prefetched Keys',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: prefetchedKeys.map((key) {
                return Chip(
                  label: Text(key.replaceFirst('prefetch-', '')),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                );
              }).toList(),
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
          onPressed: _isPrefetching ? null : _prefetchMultiple,
          icon: _isPrefetching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download),
          label: Text(_isPrefetching ? 'Prefetching...' : 'Prefetch All'),
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

  Widget _buildNavigationButtons() {
    final queryClient = context.queryClient;
    if (queryClient == null) {
      return const SizedBox.shrink();
    }

    final keys = queryClient.cache.getCacheKeys();
    final hasPrefetched = keys.any((key) => key.startsWith('prefetch-'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Navigate to Pages',
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
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.people, color: Colors.blue),
                title: const Text('Users Page'),
                subtitle: Text(
                  keys.contains(QueryKeys.prefetchUsers.key)
                      ? '✅ Prefetched - will load instantly'
                      : '❌ Not prefetched - will fetch from network',
                  style: TextStyle(
                    fontSize: 12,
                    color: keys.contains('prefetch-users')
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.article, color: Colors.orange),
                title: const Text('Posts Page'),
                subtitle: Text(
                  keys.contains(QueryKeys.prefetchPosts.key)
                      ? '✅ Prefetched - will load instantly'
                      : '❌ Not prefetched - will fetch from network',
                  style: TextStyle(
                    fontSize: 12,
                    color: keys.contains('prefetch-posts')
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const _PostsPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.checklist, color: Colors.purple),
                title: const Text('Todos Page'),
                subtitle: Text(
                  keys.contains(QueryKeys.prefetchTodos.key)
                      ? '✅ Prefetched - will load instantly'
                      : '❌ Not prefetched - will fetch from network',
                  style: TextStyle(
                    fontSize: 12,
                    color: keys.contains('prefetch-todos')
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const _TodosPage(),
                    ),
                  );
                },
              ),
            ],
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
        queryClient.cache.getCacheKeys().contains(QueryKeys.prefetchUsers.key);

    _usersQuery = queryClient.getQuery<List<User>>(
      QueryKeys.prefetchUsers,
      queryFn: () => ApiService.fetchUsers(),
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

class _PostsPage extends StatefulWidget {
  const _PostsPage();

  @override
  State<_PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<_PostsPage> {
  Query<List<Post>>? _postsQuery;
  QueryState<List<Post>>? _state;
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
        queryClient.cache.getCacheKeys().contains(QueryKeys.prefetchPosts.key);

    _postsQuery = queryClient.getQuery<List<Post>>(
      QueryKeys.prefetchPosts,
      queryFn: () => ApiService.fetchPosts(),
    );

    _state = _postsQuery!.state;
    _loadedFromCache = hasCache && _state?.hasData == true;

    _postsQuery!.stream.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
        });
      }
    });

    if (!_loadedFromCache) {
      _postsQuery!.fetch();
    }
  }

  @override
  void dispose() {
    _postsQuery?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts Page'),
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
            child: _postsQuery == null || _state == null
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
                                  final post = _state!.data![index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: const Icon(Icons.article),
                                      title: Text(post.title),
                                      subtitle: Text(
                                        post.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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

class _TodosPage extends StatefulWidget {
  const _TodosPage();

  @override
  State<_TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<_TodosPage> {
  Query<List<Todo>>? _todosQuery;
  QueryState<List<Todo>>? _state;
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
        queryClient.cache.getCacheKeys().contains(QueryKeys.prefetchTodos.key);

    _todosQuery = queryClient.getQuery<List<Todo>>(
      QueryKeys.prefetchTodos,
      queryFn: () => ApiService.fetchTodos(),
    );

    _state = _todosQuery!.state;
    _loadedFromCache = hasCache && _state?.hasData == true;

    _todosQuery!.stream.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
        });
      }
    });

    if (!_loadedFromCache) {
      _todosQuery!.fetch();
    }
  }

  @override
  void dispose() {
    _todosQuery?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos Page'),
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
            child: _todosQuery == null || _state == null
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
                                  final todo = _state!.data![index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Icon(
                                        todo.completed
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: todo.completed
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                      title: Text(todo.title),
                                      trailing: todo.completed
                                          ? const Icon(Icons.done,
                                              color: Colors.green)
                                          : null,
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
