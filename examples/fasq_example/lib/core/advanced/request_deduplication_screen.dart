import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../query_keys.dart';

class RequestDeduplicationScreen extends StatefulWidget {
  const RequestDeduplicationScreen({super.key});

  @override
  State<RequestDeduplicationScreen> createState() =>
      _RequestDeduplicationScreenState();
}

class _RequestDeduplicationScreenState
    extends State<RequestDeduplicationScreen> {
  late QueryClient _queryClient;
  late Query<List<User>> _usersQuery;
  StreamSubscription? _subscription;
  final List<String> _eventLog = [];
  int _fetchCount = 0;
  int _fetchAttempts = 0;
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient();
    _initializeQuery();
  }

  void _initializeQuery() {
    _usersQuery = Query<List<User>>(
      queryKey: QueryKeys.users,
      queryFn: () async {
        _fetchCount++;
        _addLog('🌐 Network request #$_fetchCount - Fetching users...');
        await Future.delayed(const Duration(milliseconds: 1500));
        return ApiService.fetchUsers();
      },
      cache: _queryClient.cache,
    );

    _subscription = _usersQuery.stream.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });

    // Initial fetch
    _usersQuery.fetch();
  }

  void _addLog(String message) {
    setState(() {
      _eventLog.insert(0, message);
      if (_eventLog.length > 20) {
        _eventLog.removeLast();
      }
    });
  }

  void _refetch() {
    _fetchAttempts++;
    _lastFetchTime = DateTime.now();
    _addLog('🔄 Fetch attempt #$_fetchAttempts');
    _usersQuery.fetch();
  }

  void _simulateMultipleRequests() {
    _addLog('🔄 Simulating 5 simultaneous fetches...');
    for (int i = 0; i < 5; i++) {
      _fetchAttempts++;
      _addLog('🔄 Fetch attempt #$_fetchAttempts');
      _usersQuery.fetch();
    }
  }

  void _clearLog() {
    setState(() {
      _eventLog.clear();
      _fetchCount = 0;
      _fetchAttempts = 0;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _usersQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _usersQuery.state;

    return ExampleScaffold(
      title: 'Request Deduplication',
      description:
          'Demonstrates automatic request deduplication. Multiple calls to the same query key result in a single network request. Subsequent calls receive the same response.',
      codeSnippet: '''
// Multiple widgets calling the same query
QueryBuilder<List<User>>(
  key: 'users',
  queryFn: () => api.fetchUsers(),
  builder: (context, state) {
    return UserList(state.data);
  },
)

// Even if called simultaneously from 5 places:
// ✅ Only 1 network request is made
// ✅ All 5 requests get the same response
// ✅ Prevents duplicate API calls
// ✅ Reduces server load

// Benefits:
// - Multiple widgets share same query
// - Automatic deduplication in cache
// - No race conditions
// - Single source of truth
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
                  _buildStats(),
                  const SizedBox(height: 16),
                  _buildQueryDisplay(state),
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
                'Request Deduplication Explained:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'When multiple parts of your app request the same data:\n'
            '✅ Fetch Attempts: Number of times fetch() was called\n'
            '✅ Network Requests: Actual HTTP calls made\n'
            '✅ Deduplication: Same attempt = same request\n'
            '✅ Automatic - no extra code needed\n\n'
            'Try "5 Simultaneous Fetches" → 5 attempts, only 1 network call!',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildStatItem('Fetch Attempts', '$_fetchAttempts'),
              _buildStatItem('Network Requests', '$_fetchCount'),
              _buildStatItem(
                  'Last Fetch',
                  _lastFetchTime != null
                      ? '${DateTime.now().difference(_lastFetchTime!).inSeconds}s ago'
                      : 'Never'),
            ],
          ),
          if (_fetchAttempts > 0 && _fetchAttempts > _fetchCount) ...[
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
                      '✅ Deduplication working! $_fetchAttempts attempts = $_fetchCount network calls',
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
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildQueryDisplay(QueryState<List<User>> state) {
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
            children: [
              Icon(
                state.isLoading ? Icons.refresh : Icons.check_circle,
                color: state.isLoading ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                'Users Query State',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.isLoading) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Text(
              'Fetching... (Multiple fetches = Single request)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue),
            ),
          ] else if (state.hasData) ...[
            Text(
              '✓ ${state.data!.length} users loaded',
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Even if you clicked fetch 5 times, only 1 network request was made!',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (state.hasError) ...[
            Text(
              'Error: ${state.error}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Actions',
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
              onPressed: _refetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Single Fetch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _simulateMultipleRequests,
              icon: const Icon(Icons.change_circle),
              label: const Text('5 Simultaneous Fetches'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _clearLog,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Log'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
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
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _eventLog.isEmpty
                ? Center(
                    child: Text(
                      'Events will appear here...\nTry "5 Simultaneous Fetches" to see deduplication!',
                      textAlign: TextAlign.center,
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
                      final isNetworkRequest = log.contains('🌐');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isNetworkRequest
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isNetworkRequest
                                  ? Icons.cloud_download
                                  : Icons.info,
                              size: 16,
                              color:
                                  isNetworkRequest ? Colors.blue : Colors.grey,
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
}
