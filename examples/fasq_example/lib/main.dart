import 'dart:convert';

import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'infinite_list_page_number.dart';
import 'infinite_list_cursor.dart';
import 'infinite_list_load_more.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Query Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Query Examples'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Phase 2: Caching Layer Examples',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Demonstrating intelligent caching, staleness, and request deduplication',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildExampleCard(
            context,
            'Fresh vs Stale Cache',
            'See instant cache hits and background refetching',
            Icons.cached,
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FreshStaleExamplePage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            'Request Deduplication',
            '100 widgets = 1 network call',
            Icons.call_merge,
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DeduplicationExamplePage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            'Cache Invalidation',
            'Invalidate and refetch cached data',
            Icons.refresh,
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const InvalidationExamplePage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            'Cache Metrics',
            'Monitor cache performance in real-time',
            Icons.analytics,
            Colors.purple,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CacheMetricsPage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            'Multiple Queries',
            'Query sharing demonstration',
            Icons.share,
            Colors.teal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MultipleQueriesPage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            'Error Handling',
            'Error states and recovery',
            Icons.error_outline,
            Colors.red,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ErrorHandlingPage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            'Form Submission & Mutations',
            'Create, update, delete with mutations',
            Icons.edit_document,
            Colors.indigo,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MutationExamplePage()),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Phase 4: Infinite Queries',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cursor, page-number, and load-more patterns',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildExampleCard(
            context,
            'Infinite - Page Number',
            'Scroll + load more (page index based)',
            Icons.format_list_numbered,
            Colors.blueGrey,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const InfiniteListPageNumberPage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            'Infinite - Cursor',
            'Cursor-based pagination demo',
            Icons.swap_horiz,
            Colors.deepPurple,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InfiniteListCursorPage()),
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleCard(
            context,
            'Load More Button',
            'Manual load more UX',
            Icons.add_circle_outline,
            Colors.brown,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const InfiniteListLoadMorePage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class FreshStaleExamplePage extends StatefulWidget {
  const FreshStaleExamplePage({super.key});

  @override
  State<FreshStaleExamplePage> createState() => _FreshStaleExamplePageState();
}

class _FreshStaleExamplePageState extends State<FreshStaleExamplePage> {
  Duration staleTime = const Duration(seconds: 10);

  Future<List<dynamic>> fetchUsers() async {
    final response = await http.get(
      Uri.parse('https://jsonplaceholder.typicode.com/users'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load users');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fresh vs Stale Cache'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Caching Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                    'StaleTime: ${staleTime.inSeconds}s (data fresh for ${staleTime.inSeconds}s)'),
                Slider(
                  value: staleTime.inSeconds.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '${staleTime.inSeconds}s',
                  onChanged: (value) {
                    setState(() {
                      staleTime = Duration(seconds: value.toInt());
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Navigate away and back within the stale time to see instant loading from cache!',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          Expanded(
            child: QueryBuilder<List<dynamic>>(
              queryKey: 'fresh-stale-users',
              queryFn: fetchUsers,
              options: QueryOptions(
                staleTime: staleTime,
                cacheTime: const Duration(minutes: 5),
              ),
              builder: (context, state) {
                return Column(
                  children: [
                    if (state.isFetching)
                      Container(
                        color: Colors.orange.shade100,
                        padding: const EdgeInsets.all(8),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Background refetch in progress...',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    if (state.isLoading && !state.hasData)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Fetching users from API...'),
                            ],
                          ),
                        ),
                      ),
                    if (state.hasError)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${state.error}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  QueryClient()
                                      .invalidateQuery('fresh-stale-users');
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (state.hasData)
                      Expanded(
                        child: ListView.builder(
                          itemCount: state.data!.length,
                          itemBuilder: (context, index) {
                            final user = state.data![index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(user['id'].toString()),
                              ),
                              title: Text(user['name']),
                              subtitle: Text(user['email']),
                              trailing: state.dataUpdatedAt != null
                                  ? Text(
                                      _formatTimeSince(state.dataUpdatedAt!),
                                      style: const TextStyle(fontSize: 11),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          QueryClient().invalidateQuery('fresh-stale-users');
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Force Refetch'),
      ),
    );
  }

  String _formatTimeSince(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s ago';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else {
      return '${duration.inHours}h ago';
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How Caching Works'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fresh Data (age < staleTime):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Served instantly from cache'),
              const Text('• No refetch triggered'),
              const Text('• No loading indicator'),
              const SizedBox(height: 12),
              const Text(
                'Stale Data (age >= staleTime):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Served instantly from cache'),
              const Text('• Background refetch triggered'),
              const Text('• "isFetching" indicator shows'),
              const Text('• UI updates when fresh data arrives'),
              const SizedBox(height: 12),
              const Text(
                'Try This:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. Load data (wait for fetch)'),
              Text('2. Navigate back'),
              Text('3. Return within ${staleTime.inSeconds}s'),
              const Text('4. See instant loading!'),
              const SizedBox(height: 8),
              Text('5. Wait ${staleTime.inSeconds}s+, then return'),
              const Text('6. See background refetch indicator'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class DeduplicationExamplePage extends StatelessWidget {
  const DeduplicationExamplePage({super.key});

  Future<String> fetchData() async {
    await Future.delayed(const Duration(seconds: 2));
    return 'Shared Data (fetched at ${DateTime.now().second}s)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Deduplication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 What to Watch:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('All 5 widgets below use the same query key.'),
                  Text('Notice: Only ONE fetch happens (2s delay)!'),
                  Text('All widgets receive the same result simultaneously.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildQueryWidget('Widget #1', Colors.blue),
            const SizedBox(height: 12),
            _buildQueryWidget('Widget #2', Colors.green),
            const SizedBox(height: 12),
            _buildQueryWidget('Widget #3', Colors.orange),
            const SizedBox(height: 12),
            _buildQueryWidget('Widget #4', Colors.purple),
            const SizedBox(height: 12),
            _buildQueryWidget('Widget #5', Colors.teal),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                QueryClient().invalidateQuery('dedup-demo');
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Invalidate & Refetch'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryWidget(String label, Color color) {
    return QueryBuilder<String>(
      queryKey: 'dedup-demo',
      queryFn: fetchData,
      options: const QueryOptions(
        staleTime: Duration(seconds: 30),
      ),
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.isLoading && !state.hasData)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading...'),
                        ],
                      ),
                    if (state.isFetching && state.hasData)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Refetching...'),
                        ],
                      ),
                    if (state.hasData && !state.isFetching)
                      Text(
                        'Data: ${state.data}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (state.hasError)
                      Text(
                        'Error: ${state.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
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
}

class InvalidationExamplePage extends StatefulWidget {
  const InvalidationExamplePage({super.key});

  @override
  State<InvalidationExamplePage> createState() =>
      _InvalidationExamplePageState();
}

class _InvalidationExamplePageState extends State<InvalidationExamplePage> {
  int serverVersion = 1;

  Future<Map<String, dynamic>> fetchUserData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'id': 123,
      'name': 'John Doe',
      'version': serverVersion,
      'updated': DateTime.now().toIso8601String(),
    };
  }

  void simulateServerUpdate() {
    setState(() {
      serverVersion++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server updated to version $serverVersion'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Invalidation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scenario:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('1. Data is cached with 30s staleTime'),
                  const Text('2. "Update on server" increments version'),
                  const Text('3. Use invalidation to force refetch'),
                  const Text('4. See new version loaded'),
                  const SizedBox(height: 8),
                  Text(
                    'Current Server Version: $serverVersion',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: QueryBuilder<Map<String, dynamic>>(
                queryKey: 'user-data',
                queryFn: fetchUserData,
                options: const QueryOptions(
                  staleTime: Duration(seconds: 30),
                ),
                builder: (context, state) {
                  if (state.isLoading && !state.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.hasError) {
                    return Center(child: Text('Error: ${state.error}'));
                  }

                  if (state.hasData) {
                    final data = state.data!;
                    return Center(
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (state.isFetching)
                                const LinearProgressIndicator(),
                              if (state.isFetching) const SizedBox(height: 16),
                              const Icon(Icons.person,
                                  size: 64, color: Colors.blue),
                              const SizedBox(height: 16),
                              Text(
                                data['name'],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('ID: ${data['id']}'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Version: ${data['version']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Updated: ${data['updated']}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: simulateServerUpdate,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Update on Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      QueryClient().invalidateQuery('user-data');
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Invalidate Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CacheMetricsPage extends StatefulWidget {
  const CacheMetricsPage({super.key});

  @override
  State<CacheMetricsPage> createState() => _CacheMetricsPageState();
}

class _CacheMetricsPageState extends State<CacheMetricsPage> {
  Future<String> fetchData(String key) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'Data for $key';
  }

  void _refreshMetrics() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cacheInfo = QueryClient().getCacheInfo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Metrics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMetrics,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cache Statistics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildMetricRow(
                  'Entries',
                  '${cacheInfo.entryCount}',
                  Icons.storage,
                ),
                _buildMetricRow(
                  'Size',
                  '${(cacheInfo.sizeBytes / 1024).toStringAsFixed(1)} KB',
                  Icons.data_usage,
                ),
                _buildMetricRow(
                  'Usage',
                  '${(cacheInfo.usagePercentage * 100).toStringAsFixed(1)}%',
                  Icons.pie_chart,
                ),
                _buildMetricRow(
                  'Hits',
                  '${cacheInfo.metrics.hits}',
                  Icons.check_circle,
                  color: Colors.green,
                ),
                _buildMetricRow(
                  'Misses',
                  '${cacheInfo.metrics.misses}',
                  Icons.cancel,
                  color: Colors.orange,
                ),
                _buildMetricRow(
                  'Hit Rate',
                  '${(cacheInfo.metrics.hitRate * 100).toStringAsFixed(1)}%',
                  Icons.analytics,
                  color: Colors.blue,
                ),
                _buildMetricRow(
                  'Evictions',
                  '${cacheInfo.metrics.evictions}',
                  Icons.delete_sweep,
                  color: Colors.red,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Test Cache Operations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    for (var i = 0; i < 5; i++) {
                      QueryClient().invalidateQuery('test-$i');
                      await Future.delayed(const Duration(milliseconds: 100));
                    }
                    _refreshMetrics();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create 5 Queries'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    for (var i = 0; i < 5; i++) {
                      QueryClient().getQueryData('test-$i');
                    }
                    _refreshMetrics();
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Access 5 Queries (generates hits)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    QueryClient().getQueryData('non-existent-1');
                    QueryClient().getQueryData('non-existent-2');
                    QueryClient().getQueryData('non-existent-3');
                    _refreshMetrics();
                  },
                  icon: const Icon(Icons.search_off),
                  label: const Text('Access Non-existent (generates misses)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    QueryClient().invalidateQueriesWithPrefix('test-');
                    _refreshMetrics();
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Invalidate with Prefix "test-"'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    QueryClient().clear();
                    _refreshMetrics();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Cached Keys:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...QueryClient().getCacheKeys().map((key) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(key,
                            style: const TextStyle(fontFamily: 'monospace')),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class MultipleQueriesPage extends StatelessWidget {
  const MultipleQueriesPage({super.key});

  Future<String> fetchData() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'Shared Data (${DateTime.now().second}s)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiple Queries Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'All three widgets below share the same query.\nNotice only ONE fetch happens!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildQueryWidget('Widget A', Colors.blue),
            const SizedBox(height: 16),
            _buildQueryWidget('Widget B', Colors.green),
            const SizedBox(height: 16),
            _buildQueryWidget('Widget C', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryWidget(String label, Color color) {
    return QueryBuilder<String>(
      queryKey: 'shared-data',
      queryFn: fetchData,
      options: const QueryOptions(
        staleTime: Duration(minutes: 1),
      ),
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              if (state.isLoading && !state.hasData)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading...'),
                  ],
                ),
              if (state.hasData) Text('Data: ${state.data}'),
              if (state.hasError) Text('Error: ${state.error}'),
            ],
          ),
        );
      },
    );
  }
}

class ErrorHandlingPage extends StatefulWidget {
  const ErrorHandlingPage({super.key});

  @override
  State<ErrorHandlingPage> createState() => _ErrorHandlingPageState();
}

class _ErrorHandlingPageState extends State<ErrorHandlingPage> {
  bool shouldFail = true;

  Future<String> fetchWithError() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (shouldFail) {
      throw Exception('Simulated network error');
    }

    return 'Success! Error was resolved.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Handling Example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'This example simulates an error and shows recovery',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              QueryBuilder<String>(
                queryKey: 'error-demo',
                queryFn: fetchWithError,
                builder: (context, state) {
                  if (state.isLoading && !state.hasData) {
                    return const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading...'),
                      ],
                    );
                  }

                  if (state.hasError) {
                    return Column(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${state.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                QueryClient().invalidateQuery('error-demo');
                              },
                              child: const Text('Retry'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() => shouldFail = false);
                                QueryClient().invalidateQuery('error-demo');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Fix & Retry'),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  if (state.hasData) {
                    return Column(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 64, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          state.data!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }

                  return const Text('No data');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MutationExamplePage extends StatefulWidget {
  const MutationExamplePage({super.key});

  @override
  State<MutationExamplePage> createState() => _MutationExamplePageState();
}

class _MutationExamplePageState extends State<MutationExamplePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  int _userIdCounter = 1;
  List<Map<String, dynamic>> _createdUsers = [];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> createUser(Map<String, String> userData) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (userData['name']!.isEmpty) {
      throw Exception('Name cannot be empty');
    }

    final newUser = {
      'id': _userIdCounter++,
      'name': userData['name'],
      'email': userData['email'],
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _createdUsers.add(newUser);
    });

    return newUser;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Submission & Mutations'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mutations for Server Operations',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('Use MutationBuilder for:'),
                  Text('• Creating new records (POST)'),
                  Text('• Updating existing data (PUT/PATCH)'),
                  Text('• Deleting records (DELETE)'),
                  SizedBox(height: 8),
                  Text(
                    'Try submitting the form below!',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    MutationBuilder<Map<String, dynamic>, Map<String, String>>(
                  mutationFn: createUser,
                  options: MutationOptions(
                    onSuccess: (user) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('User created: ${user['name']}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _nameController.clear();
                      _emailController.clear();
                    },
                    onError: (error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                  ),
                  builder: (context, state, mutate) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create New User',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          enabled: !state.isLoading,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          enabled: !state.isLoading,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: state.isLoading
                                ? null
                                : () {
                                    mutate({
                                      'name': _nameController.text,
                                      'email': _emailController.text,
                                    });
                                  },
                            icon: state.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: Text(state.isLoading
                                ? 'Creating...'
                                : 'Create User'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${state.error}',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Created Users:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_createdUsers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No users created yet.\nFill in the form above and click "Create User"!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ..._createdUsers.map((user) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Text(
                        user['id'].toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(user['name']),
                    subtitle: Text(user['email']),
                    trailing: Text(
                      _formatTime(user['createdAt']),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    final dateTime = DateTime.parse(isoString);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}
