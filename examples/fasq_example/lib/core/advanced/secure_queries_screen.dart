import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class SecureQueriesScreen extends StatefulWidget {
  const SecureQueriesScreen({super.key});

  @override
  State<SecureQueriesScreen> createState() => _SecureQueriesScreenState();
}

class _SecureQueriesScreenState extends State<SecureQueriesScreen> {
  late QueryClient _queryClient;
  late Query<User> _regularQuery;
  late Query<User> _secureQuery;
  StreamSubscription? _regularSubscription;
  StreamSubscription? _secureSubscription;
  final List<String> _eventLog = [];
  DateTime? _regularCreatedAt;
  DateTime? _secureCreatedAt;

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient();
    _initializeQueries();
  }

  void _initializeQueries() {
    // Regular Query (non-secure)
    _regularQuery = Query<User>(
      key: 'user-regular',
      queryFn: () => ApiService.fetchUser(1),
      cache: _queryClient.cache,
      options: QueryOptions(
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 10),
      ),
    );

    _regularSubscription = _regularQuery.stream.listen((state) {
      if (mounted && state.hasData) {
        setState(() {
          if (_regularCreatedAt == null) {
            _regularCreatedAt = DateTime.now();
          }
        });
      }
    });

    // Secure Query
    _secureQuery = Query<User>(
      key: 'user-secure',
      queryFn: () => ApiService.fetchUser(2),
      cache: _queryClient.cache,
      options: QueryOptions(
        isSecure: true,
        maxAge: const Duration(seconds: 30), // Short TTL for demo
      ),
    );

    _secureSubscription = _secureQuery.stream.listen((state) {
      if (mounted && state.hasData) {
        setState(() {
          if (_secureCreatedAt == null) {
            _secureCreatedAt = DateTime.now();
          }
        });
      }
    });

    // Fetch both
    _regularQuery.fetch();
    _secureQuery.fetch();
  }

  void _addLog(String message) {
    setState(() {
      _eventLog.insert(
          0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (_eventLog.length > 20) {
        _eventLog.removeLast();
      }
    });
  }

  void _refetchRegular() {
    _addLog('Refetching regular query...');
    _regularQuery.fetch();
  }

  void _refetchSecure() {
    _addLog('Refetching secure query...');
    _secureQuery.fetch();
  }

  void _checkCacheStatus() {
    final regularEntry = _queryClient.cache.inspectEntry('user-regular');
    final secureEntry = _queryClient.cache.inspectEntry('user-secure');

    if (regularEntry != null) {
      _addLog('Regular: cached, age: ${regularEntry.age.inSeconds}s');
    } else {
      _addLog('Regular: not in cache');
    }

    if (secureEntry != null) {
      _addLog(
          'Secure: cached, expires: ${secureEntry.expiresAt != null ? "${secureEntry.expiresAt!.difference(DateTime.now()).inSeconds}s" : "no expiry"}');
    } else {
      _addLog('Secure: not in cache (expired or not persisted)');
    }
  }

  void _clearCache() {
    _queryClient.cache.clear();
    _addLog('Cache cleared');
    setState(() {
      _regularCreatedAt = null;
      _secureCreatedAt = null;
    });
  }

  void _clearSecureEntries() {
    _queryClient.cache.clearSecureEntries();
    _addLog('Secure entries cleared');
  }

  @override
  void dispose() {
    _regularSubscription?.cancel();
    _secureSubscription?.cancel();
    _regularQuery.dispose();
    _secureQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regularState = _regularQuery.state;
    final secureState = _secureQuery.state;

    return ExampleScaffold(
      title: 'Secure Queries',
      description:
          'Demonstrates secure query handling for sensitive data. Secure queries have enforced TTL, are never persisted to disk, and are automatically cleared on expiration.',
      codeSnippet: '''
// Regular Query
Query<User>(
  key: 'user',
  queryFn: () => api.fetchUser(1),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(minutes: 10),
  ),
)

// Secure Query
Query<User>(
  key: 'user-secure',
  queryFn: () => api.fetchUser(1),
  options: QueryOptions(
    isSecure: true,
    maxAge: Duration(minutes: 1), // Required TTL
  ),
)

// Secure Query Features:
// - Enforced TTL (maxAge required)
// - Never persisted to disk
// - Auto-expires after TTL
// - Excluded from production logs
// - Can be cleared separately
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
                  _buildQueriesDisplay(regularState, secureState),
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
                Icons.lock,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Secure Queries Explained:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Secure queries protect sensitive data:\n'
            '🔒 Enforced TTL (auto-expires)\n'
            '🚫 Never persisted to disk\n'
            '🧹 Auto-cleared on expiration\n'
            '📝 Excluded from production logs\n'
            '🔐 Separate from regular cache\n\n'
            'Watch the secure query expire after 30 seconds!',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildQueriesDisplay(
      QueryState<User> regularState, QueryState<User> secureState) {
    return Row(
      children: [
        Expanded(
          child: _buildQueryCard(
            'Regular Query',
            regularState,
            Colors.blue,
            _regularCreatedAt,
            false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQueryCard(
            'Secure Query',
            secureState,
            Colors.orange,
            _secureCreatedAt,
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildQueryCard(
    String title,
    QueryState<User> state,
    Color color,
    DateTime? createdAt,
    bool isSecure,
  ) {
    String ageText = 'N/A';
    if (createdAt != null) {
      final age = DateTime.now().difference(createdAt);
      ageText = '${age.inSeconds}s';
    }

    String statusText = 'Loading...';
    if (state.hasData) {
      statusText = '✓ Loaded';
    } else if (state.hasError) {
      statusText = 'Error';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSecure ? Icons.lock : Icons.public,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Status: $statusText', style: const TextStyle(fontSize: 12)),
          Text('Age: $ageText', style: const TextStyle(fontSize: 12)),
          if (isSecure)
            Text(
              'TTL: 30s',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
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
              onPressed: _refetchRegular,
              icon: const Icon(Icons.refresh),
              label: const Text('Refetch Regular'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _refetchSecure,
              icon: const Icon(Icons.refresh),
              label: const Text('Refetch Secure'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _checkCacheStatus,
              icon: const Icon(Icons.search),
              label: const Text('Check Cache'),
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All'),
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
                      'Events will appear here...',
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
                        padding: const EdgeInsets.only(bottom: 4),
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
