import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class CursorPaginationScreen extends StatefulWidget {
  const CursorPaginationScreen({super.key});

  @override
  State<CursorPaginationScreen> createState() => _CursorPaginationScreenState();
}

class _CursorPaginationScreenState extends State<CursorPaginationScreen> {
  late InfiniteQuery<List<Post>, String?> _query;
  StreamSubscription<InfiniteQueryState<List<Post>, String?>>? _subscription;
  InfiniteQueryState<List<Post>, String?> _state = InfiniteQueryState.idle();

  @override
  void initState() {
    super.initState();
    _initializeQuery();
  }

  void _initializeQuery() {
    final client = QueryClient();
    _query = client.getInfiniteQuery<List<Post>, String?>(
      'posts-cursor',
      (cursor) => _fetchPostsWithCursor(cursor),
      options: InfiniteQueryOptions<List<Post>, String?>(
        enabled: false,
        getNextPageParam: (pages, lastPageData) {
          if (lastPageData == null || lastPageData.isEmpty) {
            return null;
          }
          final lastPost = lastPageData.last;
          return '${lastPost.id + 1}';
        },
        maxPages: 5,
      ),
    );

    _state = _query.state;

    _query.addListener();
    _subscription = _query.stream.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
        });
      }
    });

    // Manually trigger the first fetch
    Future.microtask(() {
      if (mounted) {
        _query.fetchNextPage('1');
      }
    });
  }

  Future<List<Post>> _fetchPostsWithCursor(String? cursor) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final cursorValue = cursor == null ? 0 : int.tryParse(cursor) ?? 0;
    final posts = await ApiService.fetchPostsPaginated(
      (cursorValue ~/ 10) + 1,
      limit: 5,
    );

    return posts;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _query.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Cursor Pagination',
      description:
          'Demonstrates cursor-based pagination using InfiniteQuery. Posts are loaded incrementally with a cursor-based pagination strategy.',
      codeSnippet: '''
final query = QueryClient().getInfiniteQuery<List<Post>, String?>(
  'posts-cursor',
  (cursor) => fetchPostsWithCursor(cursor),
  options: InfiniteQueryOptions<List<Post>, String?>(
    getNextPageParam: (pages, lastPageData) {
      if (lastPageData == null || lastPageData.isEmpty) {
        return null;
      }
      final lastPost = lastPageData.last;
      return '\${lastPost.id + 1}';
    },
    maxPages: 5,
  ),
);

// Load next page
await query.fetchNextPage();

// Check states
if (query.state.hasNextPage) { /* show Load More */ }
if (query.state.isFetchingNextPage) { /* show spinner */ }
''',
      child: Column(
        children: [
          _buildStats(),
          const SizedBox(height: 16),
          _buildControls(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildPostsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final allPosts = <Post>[
      for (final page in _state.pages)
        if (page.data != null) ...page.data as List<Post>
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Pages',
            '${_state.pages.length}',
            Icons.layers,
          ),
          _buildStatItem(
            'Posts',
            '${allPosts.length}',
            Icons.article,
          ),
          _buildStatItem(
            'Has Next',
            _state.hasNextPage ? 'Yes' : 'No',
            _state.hasNextPage ? Icons.check_circle : Icons.cancel,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _state.isFetchingNextPage || !_state.hasNextPage
                ? null
                : () => _query.fetchNextPage(),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Load More Posts'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _query.reset(),
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsList() {
    final allPosts = <Post>[
      for (final page in _state.pages)
        if (page.data != null) ...page.data as List<Post>
    ];
    final errorPages =
        _state.pages.where((page) => page.error != null).toList();

    if (_state.pages.isEmpty && _state.status == QueryStatus.loading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading posts...'),
            ],
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.article,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Posts (${allPosts.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: allPosts.length +
                  (errorPages.isNotEmpty ? 1 : 0) +
                  (_state.isFetchingNextPage ? 1 : 0) +
                  (_state.hasNextPage && !_state.isFetchingNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < allPosts.length) {
                  final post = allPosts[index];
                  final pageIndex = _getPageIndexForPost(post.id, allPosts);
                  return _buildPostCard(post, pageIndex);
                } else if (errorPages.isNotEmpty && index == allPosts.length) {
                  return _buildErrorRetryCard(errorPages.first.error!);
                } else if (_state.isFetchingNextPage) {
                  return _buildLoadingIndicator();
                } else if (_state.hasNextPage) {
                  return _buildLoadMoreHint();
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  int _getPageIndexForPost(int postId, List<Post> allPosts) {
    final postIndex = allPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return 0;
    return (postIndex ~/ 5) + 1;
  }

  Widget _buildPostCard(Post post, int pageIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Post #${post.id}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Page $pageIndex',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.body,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorRetryCard(Object error) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 8),
            Text(
              'Error loading page',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _query.fetchNextPage(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading more posts...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreHint() {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.expand_more,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Swipe up to load more',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
