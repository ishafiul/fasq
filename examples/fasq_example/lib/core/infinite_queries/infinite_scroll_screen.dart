import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class InfiniteScrollScreen extends StatefulWidget {
  const InfiniteScrollScreen({super.key});

  @override
  State<InfiniteScrollScreen> createState() => _InfiniteScrollScreenState();
}

class _InfiniteScrollScreenState extends State<InfiniteScrollScreen> {
  late InfiniteQuery<List<Post>, int> _query;
  StreamSubscription<InfiniteQueryState<List<Post>, int>>? _subscription;
  InfiniteQueryState<List<Post>, int> _state = InfiniteQueryState.idle();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeQuery();
    _scrollController.addListener(_onScroll);
  }

  void _initializeQuery() {
    final client = QueryClient();
    _query = client.getInfiniteQuery<List<Post>, int>(
      'posts-infinite-scroll',
      (page) => _fetchPostsWithPage(page),
      options: InfiniteQueryOptions<List<Post>, int>(
        getNextPageParam: (pages, lastPageData) {
          if (pages.isEmpty) {
            return 1;
          }
          if (lastPageData == null || lastPageData.isEmpty) {
            return null;
          }
          return pages.length + 1;
        },
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted &&
          _query.state.pages.isEmpty &&
          !_query.state.isFetchingNextPage) {
        await _query.fetchNextPage();
      }
    });
  }

  Future<List<Post>> _fetchPostsWithPage(int page) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final posts = await ApiService.fetchPostsPaginated(page, limit: 10);
    return posts;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _state.hasNextPage &&
        !_state.isFetchingNextPage) {
      _query.fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _subscription?.cancel();
    _query.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Infinite Scroll',
      description:
          'Demonstrates infinite scroll pagination using InfiniteQuery. Posts are automatically loaded as the user scrolls near the bottom of the list. No manual buttons required.',
      codeSnippet: '''
final query = QueryClient().getInfiniteQuery<List<Post>, int>(
  'posts-infinite-scroll',
  (page) => fetchPostsWithPage(page),
  options: InfiniteQueryOptions<List<Post>, int>(
    getNextPageParam: (pages, lastPageData) {
      if (pages.isEmpty) return 1;
      if (lastPageData == null || lastPageData.isEmpty) return null;
      return pages.length + 1;
    },
  ),
);

// Auto-load on scroll
ScrollController scrollController = ScrollController();
scrollController.addListener(() {
  if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200 &&
      query.state.hasNextPage &&
      !query.state.isFetchingNextPage) {
    query.fetchNextPage();
  }
});

// Display accumulated posts from all pages
final allPosts = [
  for (final page in query.state.pages)
    if (page.data != null) ...page.data as List<Post>
];
''',
      child: Column(
        children: [
          _buildStats(),
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

  Widget _buildPostsList() {
    final allPosts = <Post>[
      for (final page in _state.pages)
        if (page.data != null) ...page.data as List<Post>
    ];
    final errorPages =
        _state.pages.where((page) => page.error != null).toList();

    if (_state.pages.isEmpty) {
      if (_state.status == QueryStatus.loading || _state.isFetchingNextPage) {
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
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: ElevatedButton.icon(
            onPressed: () => _query.fetchNextPage(),
            icon: const Icon(Icons.refresh),
            label: const Text('Load Posts'),
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
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: allPosts.length +
                  (errorPages.isNotEmpty ? 1 : 0) +
                  (_state.isFetchingNextPage ? 1 : 0) +
                  (!_state.hasNextPage && _state.pages.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < allPosts.length) {
                  final post = allPosts[index];
                  final pageIndex = _getPageIndexForPost(post);
                  return _buildPostCard(post, pageIndex);
                } else if (errorPages.isNotEmpty && index == allPosts.length) {
                  final errorPageIndex = _state.pages.indexWhere(
                    (page) => page.error != null,
                  );
                  return _buildErrorRetryCard(
                    errorPages.first.error!,
                    errorPageIndex >= 0 ? errorPageIndex : null,
                  );
                } else if (_state.isFetchingNextPage) {
                  return _buildLoadingIndicator();
                } else if (!_state.hasNextPage) {
                  return _buildEndOfList();
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  int _getPageIndexForPost(Post post) {
    for (int i = 0; i < _state.pages.length; i++) {
      final page = _state.pages[i];
      if (page.data != null) {
        final posts = page.data as List<Post>;
        if (posts.any((p) => p.id == post.id)) {
          return i + 1;
        }
      }
    }
    return 1;
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

  Widget _buildErrorRetryCard(Object error, int? errorPageIndex) {
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
              onPressed: _state.isFetchingNextPage
                  ? null
                  : () {
                      if (errorPageIndex != null && errorPageIndex >= 0) {
                        _query.refetchPage(errorPageIndex);
                      } else {
                        _query.fetchNextPage();
                      }
                    },
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

  Widget _buildEndOfList() {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'You\'ve reached the end',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
