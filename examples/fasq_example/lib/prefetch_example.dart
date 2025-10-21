import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class PrefetchExample extends StatefulWidget {
  const PrefetchExample({super.key});

  @override
  State<PrefetchExample> createState() => _PrefetchExampleState();
}

class _PrefetchExampleState extends State<PrefetchExample> {
  final QueryClient _client = QueryClient();
  String? _selectedUser;
  String? _prefetchedData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prefetch Example'),
        backgroundColor: Colors.blue[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prefetching Demo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hover over user cards to prefetch their data. Click to navigate and see instant loading!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Users (Hover to Prefetch)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: 5,
                            itemBuilder: (context, index) {
                              final userId = 'user-${index + 1}';
                              return _UserCard(
                                userId: userId,
                                onHover: () => _prefetchUserData(userId),
                                onTap: () => _navigateToUser(userId),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prefetch Status',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected User: ${_selectedUser ?? 'None'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prefetched Data: ${_prefetchedData ?? 'None'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Cache Status:',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _CacheStatus(client: _client),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'How it works:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Hover over a user card to prefetch their data\n'
              '• Click to navigate and see instant loading (no loading spinner)\n'
              '• Prefetched data is cached and reused\n'
              '• Fresh data is not re-fetched unnecessarily',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prefetchUserData(String userId) async {
    try {
      await _client.prefetchQuery(
        'user-$userId',
        () => _simulateApiCall(userId),
        options: QueryOptions(
          staleTime: Duration(seconds: 30),
        ),
      );

      if (mounted) {
        setState(() {
          _prefetchedData = 'User $userId data prefetched';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prefetch failed: $e')),
        );
      }
    }
  }

  void _navigateToUser(String userId) {
    setState(() {
      _selectedUser = userId;
    });

    // Show a dialog to simulate navigation
    showDialog(
      context: context,
      builder: (context) => _UserDetailDialog(userId: userId, client: _client),
    );
  }

  Future<String> _simulateApiCall(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Data for $userId (fetched at ${DateTime.now().toIso8601String()})';
  }
}

class _UserCard extends StatefulWidget {
  final String userId;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _UserCard({
    required this.userId,
    required this.onHover,
    required this.onTap,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
        widget.onHover();
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: Card(
        elevation: _isHovered ? 8 : 2,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _isHovered ? Colors.blue[50] : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[200],
                  child: Text(
                    widget.userId.split('-').last,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ${widget.userId.split('-').last}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _isHovered ? 'Prefetching...' : 'Hover to prefetch',
                        style: TextStyle(
                          color:
                              _isHovered ? Colors.blue[600] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isHovered)
                  Icon(
                    Icons.download,
                    color: Colors.blue[600],
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserDetailDialog extends StatelessWidget {
  final String userId;
  final QueryClient client;

  const _UserDetailDialog({
    required this.userId,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<String>(
      queryKey: 'user-$userId',
      queryFn: () => _simulateApiCall(userId),
      builder: (context, state) {
        return AlertDialog(
          title: Text('User $userId Details'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.hasError)
                  Text(
                    'Error: ${state.error}',
                    style: const TextStyle(color: Colors.red),
                  )
                else if (state.hasData)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data: ${state.data}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${state.isStale ? 'Stale' : 'Fresh'}',
                        style: TextStyle(
                          color: state.isStale ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Loaded instantly: ${state.isLoading ? 'No' : 'Yes'}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _simulateApiCall(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Data for $userId (fetched at ${DateTime.now().toIso8601String()})';
  }
}

class _CacheStatus extends StatefulWidget {
  final QueryClient client;

  const _CacheStatus({required this.client});

  @override
  State<_CacheStatus> createState() => _CacheStatusState();
}

class _CacheStatusState extends State<_CacheStatus> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final cache = widget.client.cache;
        final entries = <String, dynamic>{};

        // Get cache entries (this is a simplified view)
        for (int i = 1; i <= 5; i++) {
          final key = 'user-user-$i';
          final entry = cache.get<String>(key);
          if (entry != null) {
            entries[key] = {
              'data': entry.data,
              'isStale': entry.isStale,
              'lastUpdated': entry.createdAt,
            };
          }
        }

        if (entries.isEmpty) {
          return const Text(
            'No cached data yet.\nHover over user cards to prefetch.',
            style: TextStyle(color: Colors.grey),
          );
        }

        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries.entries.elementAt(index);
            final data = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: data['isStale'] ? Colors.orange[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: data['isStale'] ? Colors.orange : Colors.green,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Status: ${data['isStale'] ? 'Stale' : 'Fresh'}',
                    style: TextStyle(
                      color: data['isStale']
                          ? Colors.orange[700]
                          : Colors.green[700],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
