import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'package:fasq/src/cache/eviction_policy.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';

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
    _queryClient = QueryClient();
    // Set max entries to small value to trigger eviction
    _queryClient.cache.clear(); // Clear any existing data
  }

  void _switchPolicy(EvictionPolicy policy) {
    setState(() {
      _currentPolicy = policy;
    });
    
    // For demo purposes, we'll show the effect by clearing
    _clearCache();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Switched to ${policy.name.toUpperCase()} policy'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addQuery(String key, Future<dynamic> Function() queryFn) async {
    if (_queries.containsKey(key)) {
      // Already exists, just refetch
      _queries[key]!.fetch();
      return;
    }

    final query = Query(
      key: key,
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
                child: _buildPolicyButton('LRU', EvictionPolicy.lru, Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPolicyButton('LFU', EvictionPolicy.lfu, Colors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPolicyButton('FIFO', EvictionPolicy.fifo, Colors.purple),
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
      EvictionPolicy.lru: 'Removes data that hasn\'t been used recently',
      EvictionPolicy.lfu: 'Removes data that is accessed least frequently',
      EvictionPolicy.fifo: 'Removes data in order (oldest first)',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
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
                '${_currentPolicy.name.toUpperCase()} Policy:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${policyDescription[_currentPolicy]}\n\n'
            'How to test:\n'
            '1. Add queries until cache fills up\n'
            '2. Add more queries - watch which ones get evicted\n'
            '3. Access a query - see how it affects eviction order\n'
            '4. Switch policies and repeat - notice the differences',
            style: Theme.of(context).textTheme.bodySmall,
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
              onPressed: () => _addQuery('User', () => ApiService.fetchUser(1)),
              icon: const Icon(Icons.person),
              label: const Text('Add User'),
            ),
            ElevatedButton.icon(
              onPressed: () => _addQuery('Todos', () => ApiService.fetchTodos()),
              icon: const Icon(Icons.list),
              label: const Text('Add Todos'),
            ),
            ElevatedButton.icon(
              onPressed: () => _addQuery('Posts', () => ApiService.fetchPosts()),
              icon: const Icon(Icons.article),
              label: const Text('Add Posts'),
            ),
            ElevatedButton.icon(
              onPressed: () => _addQuery('More Todos', () => ApiService.fetchTodos()),
              icon: const Icon(Icons.list_alt),
              label: const Text('Add More'),
            ),
            ElevatedButton.icon(
              onPressed: () => _addQuery('Extra Posts', () => ApiService.fetchPosts()),
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
            child: Row(
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
                status = isLast ? 'Most Recent' : 'Least Recent';
              } else if (_currentPolicy == EvictionPolicy.lfu) {
                // LFU would require access count tracking
                color = Colors.orange;
                status = 'Access Count: Unknown';
              } else if (_currentPolicy == EvictionPolicy.fifo) {
                color = isFirst ? Colors.red : Colors.green;
                status = isFirst ? 'Oldest (Next to Evict)' : 'Newer';
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
