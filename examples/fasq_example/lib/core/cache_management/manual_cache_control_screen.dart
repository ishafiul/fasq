import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../query_keys.dart';

class ManualCacheControlScreen extends StatefulWidget {
  const ManualCacheControlScreen({super.key});

  @override
  State<ManualCacheControlScreen> createState() =>
      _ManualCacheControlScreenState();
}

class _ManualCacheControlScreenState extends State<ManualCacheControlScreen> {
  late QueryClient _queryClient;
  final Map<String, Query> _queries = {};
  final Map<String, dynamic> _cacheData = {};
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final queries = <(TypedQueryKey<dynamic>, Future<dynamic> Function())>[
      (QueryKeys.users, () => ApiService.fetchUsers()),
      (QueryKeys.todos, () => ApiService.fetchTodos()),
      (QueryKeys.posts, () => ApiService.fetchPosts()),
    ];

    for (final (queryKey, queryFn) in queries) {
      final query = Query(
        queryKey: queryKey,
        queryFn: queryFn,
        cache: _queryClient.cache,
      );

      final key = queryKey.key;
      _queries[key] = query;

      query.stream.listen((state) {
        if (mounted && state.hasData) {
          setState(() {
            _cacheData[key] = state.data;
          });
        }
      });

      await query.fetch();
    }
  }

  void _addLog(String message) {
    setState(() {
      _eventLog.insert(0, message);
      if (_eventLog.length > 15) {
        _eventLog.removeLast();
      }
    });
  }

  void _manualSetData() {
    const testData = {'message': 'Manually set data', 'timestamp': '2024'};
    _queryClient.cache.setData('manual-test', testData);
    _addLog('✅ Manually set data for key: manual-test');
  }

  void _getManualData() {
    final data = _queryClient.cache.getData('manual-test');
    _addLog('📖 Retrieved manual data: ${data?.toString() ?? 'Not found'}');
  }

  void _removeEntry() {
    if (_queries.isNotEmpty) {
      final key = _queries.keys.first;
      _queryClient.cache.remove(key);
      _addLog('🗑️ Removed entry: $key');
    }
  }

  void _inspectCache() {
    final info = _queryClient.cache.getCacheInfo();
    final keys = _queryClient.cache.getCacheKeys();

    _addLog(
        '📊 Cache Info: ${info.entryCount} entries, ${info.sizeBytes ~/ 1024}KB');
    _addLog('🔑 Keys: ${keys.join(', ')}');
  }

  void _clearCache() {
    _queryClient.cache.clear();
    _addLog('🗑️ Cleared entire cache');
  }

  void _clearSecureEntries() {
    _queryClient.cache.clearSecureEntries();
    _addLog('🔒 Cleared secure entries');
  }

  @override
  void dispose() {
    _queries.values.forEach((q) => q.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Manual Cache Control',
      description:
          'Demonstrates manual cache manipulation methods including setting, getting, removing, and inspecting cache entries. Perfect for programmatic cache management.',
      codeSnippet: '''
// Set data manually
cache.setData('myKey', myData);

// Get data manually  
final data = cache.getData('myKey');

// Remove entry
cache.remove('myKey');

// Clear entire cache
cache.clear();

// Clear only secure entries
cache.clearSecureEntries();

// Inspect cache
final info = cache.getCacheInfo();
final keys = cache.getCacheKeys();

// Get cache entry details
final entry = cache.inspectEntry('myKey');
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
                'Manual Cache Control:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use this screen to manually manipulate the cache:\n'
            '• Set custom data directly\n'
            '• Retrieve cached data programmatically\n'
            '• Remove specific entries\n'
            '• Inspect cache statistics\n'
            '• Clear all or secure entries\n'
            'Watch the event log to see each operation',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCacheStatus() {
    final info = _queryClient.cache.getCacheInfo();
    final keys = _queryClient.cache.getCacheKeys();

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
          _buildStatRow('Entries', '${info.entryCount}'),
          _buildStatRow('Size', '${info.sizeBytes ~/ 1024} KB'),
          _buildStatRow('Max Size', '${info.maxCacheSize ~/ 1024 ~/ 1024} MB'),
          _buildStatRow('Cache Hits', '${info.metrics.hits}'),
          _buildStatRow('Cache Misses', '${info.metrics.misses}'),
          if (keys.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Cache Keys (${keys.length})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: keys.map((key) {
                return Chip(
                  label: Text(key),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _manualSetData,
              icon: const Icon(Icons.add),
              label: const Text('Set Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _getManualData,
              icon: const Icon(Icons.read_more),
              label: const Text('Get Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _removeEntry,
              icon: const Icon(Icons.delete),
              label: const Text('Remove Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _inspectCache,
              icon: const Icon(Icons.info),
              label: const Text('Inspect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _clearSecureEntries,
              icon: const Icon(Icons.lock_open),
              label: const Text('Clear Secure'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
                onPressed: () {
                  setState(() {
                    _eventLog.clear();
                  });
                },
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
                      'Actions will appear here...',
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
                        padding: const EdgeInsets.only(bottom: 8),
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
