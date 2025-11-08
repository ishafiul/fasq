import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../query_keys.dart';

class CacheTimeScreen extends StatefulWidget {
  const CacheTimeScreen({super.key});

  @override
  State<CacheTimeScreen> createState() => _CacheTimeScreenState();
}

class _CacheTimeScreenState extends State<CacheTimeScreen> {
  Duration cacheTime = const Duration(seconds: 30);
  DateTime? _firstFetchTime;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Cache Time',
      description:
          'Demonstrates how cacheTime controls how long data remains in cache after unmounting. Navigate away and back to see cached data served instantly without refetching.',
      codeSnippet: '''
QueryBuilder<List<Post>>(
  queryKey: QueryKeys.postsCacheDemo,
  queryFn: () => ApiService.fetchPosts(),
  options: QueryOptions(
    cacheTime: Duration(seconds: 30), // Data stays in cache for 30s
    staleTime: Duration(seconds: 10),  // After 10s, data is stale but still cached
  ),
  builder: (context, state) {
    if (state.isLoading && !state.hasData) {
      return LoadingWidget(message: 'First fetch...');
    }
    
    // Data served instantly from cache after unmount
    if (state.hasData) {
      return PostList(posts: state.data!);
    }
    
    return EmptyWidget(message: 'No posts found');
  },
)

// Navigate away and come back - data persists!
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          _buildControls(),
          const SizedBox(height: 16),
          Expanded(
            child: QueryBuilder<List<Post>>(
              queryKey: QueryKeys.postsCacheDemo,
              queryFn: () => _fetchPosts(),
              options: QueryOptions(
                cacheTime: cacheTime,
                staleTime: const Duration(seconds: 5),
                onSuccess: () {
                  if (_firstFetchTime == null) {
                    setState(() {
                      _firstFetchTime = DateTime.now();
                    });
                  }
                },
              ),
              builder: (context, state) {
                // Update status message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      if (state.isLoading && !state.hasData) {
                        _statusMessage =
                            '🔄 Loading... First network request in progress';
                      } else if (state.hasData) {
                        final client = QueryClient();
                        final cacheEntry = client.cache
                            .get<List<Post>>(QueryKeys.postsCacheDemo.key);
                        if (cacheEntry != null) {
                          _statusMessage =
                              '✅ Data loaded from ${cacheEntry.isFresh ? "fresh cache" : "stale cache"} (age: ${cacheEntry.age.inSeconds}s)';
                        } else {
                          _statusMessage = '✅ Data loaded from memory';
                        }
                      } else if (state.hasError) {
                        _statusMessage = '❌ Error: ${state.error}';
                      }
                    });
                  }
                });

                if (state.isLoading && !state.hasData) {
                  return const LoadingWidget(message: 'Fetching posts...');
                }

                if (state.hasError) {
                  return CustomErrorWidget(
                    message: state.error.toString(),
                    onRetry: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CacheTimeScreen(),
                        ),
                      );
                    },
                  );
                }

                if (state.hasData) {
                  return Column(
                    children: [
                      _buildStatusIndicator(state),
                      const SizedBox(height: 16),
                      Expanded(child: _buildPostList(state)),
                    ],
                  );
                }

                return const EmptyWidget(message: 'No posts found');
              },
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
                'How to see the effect:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1️⃣ First load: Data fetches from network (watch for loading spinner)\n'
            '2️⃣ Navigate away using the navigation demo\n'
            '3️⃣ Navigate back within cacheTime: Data loads instantly from cache\n'
            '4️⃣ Wait for cacheTime to expire: Next fetch shows loading again\n'
            '5️⃣ Adjust cacheTime slider to change retention duration',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(QueryState<List<Post>> state) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage.isEmpty ? 'Status: Ready' : _statusMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
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
            'Cache Time Configuration',
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
                      'Cache Time: ${cacheTime.inSeconds}s',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Slider(
                      value: cacheTime.inSeconds.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      onChanged: (value) {
                        setState(() {
                          cacheTime = Duration(seconds: value.round());
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
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const _NavigationDemoScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      QueryClient().removeQuery(QueryKeys.postsCacheDemo);
                      QueryClient().invalidateQuery(QueryKeys.postsCacheDemo);
                      setState(() {
                        _firstFetchTime = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.clear_all, color: Colors.white),
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
                              Theme.of(context).colorScheme.secondary,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
          if (_firstFetchTime != null) ...[
            const SizedBox(height: 12),
            _buildCacheInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildCacheInfo() {
    final client = QueryClient();
    final cacheEntry =
        client.cache.get<List<Post>>(QueryKeys.postsCacheDemo.key);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cacheEntry != null && cacheEntry.isFresh
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            cacheEntry != null && cacheEntry.isFresh
                ? Icons.check_circle
                : Icons.schedule,
            color: cacheEntry != null && cacheEntry.isFresh
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cacheEntry != null && cacheEntry.isFresh
                      ? 'Cache Entry Active'
                      : 'Cache Expired or Not Found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cacheEntry != null && cacheEntry.isFresh
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                      ),
                ),
                if (cacheEntry != null)
                  Text(
                    'Age: ${cacheEntry.age.inSeconds}s / ${cacheEntry.staleTime.inSeconds}s stale, ${cacheTime.inSeconds}s cache',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cacheEntry.isFresh
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(QueryState<List<Post>> state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.data!.length,
      itemBuilder: (context, index) {
        final post = state.data![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(post.id.toString()),
            ),
            title: Text(post.title),
            subtitle: Text(post.body),
            trailing: Text(
              'User ${post.userId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      },
    );
  }

  Future<List<Post>> _fetchPosts() async {
    // Simulate a timestamp-based response to show cache effectiveness
    final posts = await ApiService.fetchPosts();
    return posts;
  }
}

class _NavigationDemoScreen extends StatelessWidget {
  const _NavigationDemoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.navigation,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'You navigated away!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The cached data is still in memory',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Key Points:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoPoint(
                      context, Icons.cached, 'Cache persists after unmount'),
                  const SizedBox(height: 8),
                  _buildInfoPoint(
                      context, Icons.timer, 'Controlled by cacheTime option'),
                  const SizedBox(height: 8),
                  _buildInfoPoint(
                      context, Icons.flash_on, 'Instant load on return'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back (Data Still Cached)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPoint(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ),
      ],
    );
  }
}
