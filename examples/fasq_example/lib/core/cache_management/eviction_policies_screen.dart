import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'package:fasq/src/cache/eviction_policy.dart';
import 'package:fasq/src/cache/cache_config.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../query_keys.dart';

class EvictionPoliciesScreen extends StatefulWidget {
  const EvictionPoliciesScreen({super.key});

  @override
  State<EvictionPoliciesScreen> createState() => _EvictionPoliciesScreenState();
}

class _EvictionPoliciesScreenState extends State<EvictionPoliciesScreen> {
  late QueryClient _queryClient;
  EvictionPolicy _currentPolicy = EvictionPolicy.lru;
  final Map<String, Query> _queries = {};
  final Map<String, dynamic> _cacheData = {};
  final List<String> _evictionOrder = [];
  int _cacheSize = 0;
  int _maxEntries = 5; // Small limit to force eviction

  @override
  void initState() {
    super.initState();
    _setupCache();
  }

  void _setupCache() {
    // Create QueryClient with small maxEntries to force eviction
    _queryClient = QueryClient(
      config: CacheConfig(
        maxEntries: _maxEntries,
        evictionPolicy: _currentPolicy,
      ),
    );
    _queryClient.cache.clear(); // Clear any existing data
  }

  void _switchPolicy(EvictionPolicy policy) {
    setState(() {
      _currentPolicy = policy;
    });

    // Dispose old client
    _queries.values.forEach((q) => q.dispose());
    _queries.clear();

    // Create new QueryClient with new policy
    _queryClient = QueryClient(
      config: CacheConfig(
        maxEntries: _maxEntries,
        evictionPolicy: policy,
      ),
    );

    setState(() {
      _cacheData.clear();
      _evictionOrder.clear();
      _cacheSize = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Switched to ${policy.name.toUpperCase()} policy'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addQuery(TypedQueryKey<dynamic> queryKey) async {
    final key = queryKey.key;
    if (_queries.containsKey(key)) {
      // Already exists, just refetch
      _queries[key]!.fetch();
      return;
    }

    Future<dynamic> Function() queryFn;
    if (queryKey == QueryKeys.user(1)) {
      queryFn = () => ApiService.fetchUser(1);
    } else if (queryKey == QueryKeys.posts) {
      queryFn = ApiService.fetchPosts;
    } else if (queryKey == QueryKeys.todos) {
      queryFn = ApiService.fetchTodos;
    } else {
      throw ArgumentError('Unsupported query key: ${queryKey.key}');
    }

    final query = Query(
      queryKey: queryKey,
      queryFn: queryFn,
      cache: _queryClient.cache,
    );

    _queries[key] = query;

    // Subscribe to updates
    query.stream.listen((state) {
      if (mounted && state.hasData) {
        setState(() {
          _cacheData[key] = state.data;
        });
      }
    });

    await query.fetch();

    setState(() {
      _cacheSize = _queries.length;
    });
  }

  void _accessQuery(String key) {
    if (_queries.containsKey(key)) {
      _queries[key]!.fetch();

      // Track access in eviction order for demo
      if (!_evictionOrder.contains(key)) {
        _evictionOrder.add(key);
      } else {
        // Move to end (most recently accessed)
        _evictionOrder.remove(key);
        _evictionOrder.add(key);
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accessing $key (updated last accessed time)'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _clearCache() {
    _queries.values.forEach((q) => q.dispose());
    _queries.clear();
    _cacheData.clear();
    _evictionOrder.clear();
    _queryClient.cache.clear();

    setState(() {
      _cacheSize = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  void dispose() {
    _queries.values.forEach((q) => q.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Eviction Policies',
      description:
          'Demonstrates different cache eviction policies: LRU (Least Recently Used), LFU (Least Frequently Used), and FIFO (First In First Out). Watch how each policy behaves differently when the cache fills up.',
      codeSnippet: '''
// Configure cache with eviction policy
final config = CacheConfig(
  maxEntries: 100,
  evictionPolicy: EvictionPolicy.lru, // or lfu, fifo
);

final queryClient = QueryClient();

// Add queries to cache
// When cache fills up, entries are evicted based on policy:
// - LRU: Removes least recently used
// - LFU: Removes least frequently used  
// - FIFO: Removes oldest entries

// Best practices:
// - LRU: General purpose (default)
// - LFU: When some data is frequently reused
// - FIFO: Simplest, time-based data
''',
      child: Column(
        children: [
          _buildPolicySelector(),
          const SizedBox(height: 16),
          _buildStats(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInstructions(),
                  const SizedBox(height: 24),
                  _buildActions(),
                  const SizedBox(height: 24),
                  _buildCacheDisplay(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          Text(
            'Current Policy: ${_currentPolicy.name.toUpperCase()}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child:
                    _buildPolicyButton('LRU', EvictionPolicy.lru, Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _buildPolicyButton('LFU', EvictionPolicy.lfu, Colors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPolicyButton(
                    'FIFO', EvictionPolicy.fifo, Colors.purple),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyButton(String label, EvictionPolicy policy, Color color) {
    final isActive = _currentPolicy == policy;
    return ElevatedButton(
      onPressed: () => _switchPolicy(policy),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? color : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (isActive) ...[
            const SizedBox(height: 4),
            const Icon(Icons.check_circle, size: 16),
          ],
        ],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Cache Size', '$_cacheSize / $_maxEntries'),
          _buildStatItem('Policy', _currentPolicy.name.toUpperCase()),
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
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    final policyDescription = {
      EvictionPolicy.lru:
          'Removes the OLDEST accessed data first. Like a stack - most recent data stays',
      EvictionPolicy.lfu:
          'Removes data with the LEAST access count. Protects frequently used data',
      EvictionPolicy.fifo:
          'Removes in order - first thing added gets removed first. Like a queue',
    };

    final policyExample = {
      EvictionPolicy.lru:
          'You accessed: User → Posts → User → Todos\nEviction order: Posts, Todos, User (User is last accessed, stays)',
      EvictionPolicy.lfu:
          'Access count: User(3x), Posts(1x), Todos(2x)\nEviction order: Posts, Todos, User (Posts accessed least)',
      EvictionPolicy.fifo:
          'Added in order: User → Posts → Todos\nEviction order: User, Posts, Todos (oldest first)',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_currentPolicy.name.toUpperCase()} Policy Explained',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              policyDescription[_currentPolicy]!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Example:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            policyExample[_currentPolicy]!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.play_circle_outline,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Try This:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '1. Click "Add User" then "Add Posts"\n'
                  '2. Keep adding until you see "6 / 5" (cache full!)\n'
                  '3. Notice which items are RED (will be evicted)\n'
                  '4. Click refresh icon to change access order\n'
                  '5. Add more and see how eviction changes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        // Add queries
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _addQuery(QueryKeys.user(1)),
              icon: const Icon(Icons.person),
              label: const Text('Add User'),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  _addQuery(QueryKeys.todos),
              icon: const Icon(Icons.list),
              label: const Text('Add Todos'),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  _addQuery(QueryKeys.posts),
              icon: const Icon(Icons.article),
              label: const Text('Add Posts'),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  _addQuery(QueryKeys.todos),
              icon: const Icon(Icons.list_alt),
              label: const Text('Add More'),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  _addQuery(QueryKeys.posts),
              icon: const Icon(Icons.article_outlined),
              label: const Text('Add More'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Clear cache
        ElevatedButton.icon(
          onPressed: _clearCache,
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear Cache'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCacheDisplay() {
    if (_queries.isEmpty) {
      return Center(
        child: Text(
          'No queries in cache\nAdd some queries to see eviction behavior',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cache Entries',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${_queries.length} / $_maxEntries',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _queries.length >= _maxEntries
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (_queries.length >= _maxEntries) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cache is FULL! Adding more will evict entries marked in RED',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.red.shade700,
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
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _queries.length,
            itemBuilder: (context, index) {
              final key = _queries.keys.elementAt(index);
              final isLast = index == _evictionOrder.length - 1;
              final isFirst = index == 0;

              Color color = Colors.grey;
              String status = '';

              if (_currentPolicy == EvictionPolicy.lru) {
                color = isLast ? Colors.green : Colors.red;
                if (isLast && index == _evictionOrder.length - 1) {
                  status = '✅ Last Accessed (KEEP)';
                } else if (isFirst) {
                  status = '⚠️ Oldest Access (EVICT FIRST)';
                } else {
                  status = 'Not Recently Used';
                }
              } else if (_currentPolicy == EvictionPolicy.lfu) {
                // LFU would require access count tracking
                color = isFirst ? Colors.red : Colors.orange;
                status = isFirst
                    ? '⚠️ Least Frequent (EVICT FIRST)'
                    : 'More Frequent';
              } else if (_currentPolicy == EvictionPolicy.fifo) {
                color = isFirst ? Colors.red : Colors.green;
                status =
                    isFirst ? '⚠️ Oldest Entry (EVICT FIRST)' : '✅ Newer Entry';
              }

              return Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  border: Border(
                    left: BorderSide(color: color, width: 3),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Icon(
                      _getIconForKey(key),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(status),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _accessQuery(key),
                    tooltip: 'Access (affects LRU)',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconForKey(String key) {
    switch (key.toLowerCase()) {
      case 'user':
        return Icons.person;
      case 'todos':
        return Icons.list;
      case 'posts':
        return Icons.article;
      case 'quotes':
        return Icons.format_quote;
      case 'photos':
        return Icons.photo;
      default:
        return Icons.data_object;
    }
  }
}
