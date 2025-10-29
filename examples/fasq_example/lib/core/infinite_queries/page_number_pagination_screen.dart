import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class PageNumberPaginationScreen extends StatefulWidget {
  const PageNumberPaginationScreen({super.key});

  @override
  State<PageNumberPaginationScreen> createState() =>
      _PageNumberPaginationScreenState();
}

class _PageNumberPaginationScreenState
    extends State<PageNumberPaginationScreen> {
  late InfiniteQuery<List<Post>, int> _query;
  StreamSubscription<InfiniteQueryState<List<Post>, int>>? _subscription;
  InfiniteQueryState<List<Post>, int> _state = InfiniteQueryState.idle();
  int? _viewingPage;

  @override
  void initState() {
    super.initState();
    _initializeQuery();
  }

  void _initializeQuery() {
    final client = QueryClient();
    const maxPages = 5;
    _query = client.getInfiniteQuery<List<Post>, int>(
      'posts-page-number',
      (page) => _fetchPostsWithPage(page),
      options: InfiniteQueryOptions<List<Post>, int>(
        getNextPageParam: (pages, lastPageData) {
          if (pages.isEmpty) {
            return 1;
          }
          if (pages.length >= maxPages) {
            return null;
          }
          if (lastPageData == null || lastPageData.isEmpty) {
            return null;
          }
          final lastPage = pages.last;
          return lastPage.param + 1;
        },
        getPreviousPageParam: (pages, firstPageData) {
          if (pages.isEmpty) {
            return null;
          }
          final firstPage = pages.first;
          final firstPageNum = firstPage.param;
          if (firstPageNum <= 1) {
            return null;
          }
          return firstPageNum - 1;
        },
        maxPages: maxPages,
      ),
    );

    _state = _query.state;

    _query.addListener();
    _subscription = _query.stream.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
          if (_viewingPage == null && state.pages.isNotEmpty) {
            _viewingPage = state.pages.last.param;
          }
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
    final posts = await ApiService.fetchPostsPaginated(page, limit: 5);
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
      title: 'Page Number Pagination',
      description:
          'Demonstrates true page number-based pagination using InfiniteQuery. Shows one page at a time with Previous/Next buttons and clickable page number indicators. Users can jump to specific pages or navigate sequentially.',
      codeSnippet: '''
final query = QueryClient().getInfiniteQuery<List<Post>, int>(
  'posts-page-number',
  (page) => fetchPostsWithPage(page),
  options: InfiniteQueryOptions<List<Post>, int>(
    getNextPageParam: (pages, lastPageData) {
      if (pages.isEmpty) return 1;
      final lastPage = pages.last;
      return (lastPage.param as int) + 1;
    },
    getPreviousPageParam: (pages, firstPageData) {
      if (pages.isEmpty) return null;
      final firstPage = pages.first;
      final firstPageNum = firstPage.param as int;
      if (firstPageNum <= 1) return null;
      return firstPageNum - 1;
    },
    maxPages: 5,
  ),
);

// Navigate pages
await query.fetchNextPage();        // Next page
await query.fetchPreviousPage();    // Previous page
await query.fetchNextPage(5);       // Jump to page 5

// Display current page
final currentPage = query.state.pages.last.param as int;
final currentPosts = query.state.pages.last.data as List<Post>;
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

  int get _currentPage {
    if (_viewingPage != null) return _viewingPage!;
    if (_state.pages.isEmpty) return 1;
    return _state.pages.last.param;
  }

  List<Post> get _currentPagePosts {
    final pageToShow = _currentPage;
    final cachedPage =
        _state.pages.where((p) => p.param == pageToShow).firstOrNull;
    if (cachedPage?.data != null) {
      return cachedPage!.data as List<Post>;
    }
    return <Post>[];
  }

  void _navigateToPage(int page) {
    final cachedPage = _state.pages.where((p) => p.param == page).firstOrNull;
    if (cachedPage != null && cachedPage.data != null) {
      setState(() {
        _viewingPage = page;
      });
    } else {
      setState(() {
        _viewingPage = page;
      });
      _query.fetchNextPage(page);
    }
  }

  Widget _buildStats() {
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
            'Current Page',
            '$_currentPage',
            Icons.pageview,
          ),
          _buildStatItem(
            'Posts',
            '${_currentPagePosts.length}',
            Icons.article,
          ),
          _buildStatItem(
            'Cached Pages',
            '${_state.pages.length}',
            Icons.layers,
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
    final isFetching =
        _state.isFetchingNextPage || _state.isFetchingPreviousPage;
    final canGoPrevious = _state.hasPreviousPage && !isFetching;
    final canGoNext = _state.hasNextPage && !isFetching;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canGoPrevious
                    ? () {
                        final prevPage = _currentPage - 1;
                        _navigateToPage(prevPage);
                      }
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canGoNext
                    ? () {
                        final nextPage = _currentPage + 1;
                        _navigateToPage(nextPage);
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPageNumbers(),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: isFetching
              ? null
              : () {
                  _viewingPage = null;
                  _query.reset();
                },
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPageNumbers() {
    final currentPage = _currentPage;
    final cachedPages = _state.pages.map((p) => p.param).toList()..sort();
    final maxPage = cachedPages.isNotEmpty ? cachedPages.last : currentPage;

    final pagesToShow = <int>[];
    final startPage = (currentPage - 2).clamp(1, double.infinity).toInt();
    final endPage = (currentPage + 2).clamp(0, double.infinity).toInt();

    if (startPage > 1) {
      pagesToShow.add(1);
      if (startPage > 2) {
        pagesToShow.add(-1);
      }
    }

    for (int i = startPage; i <= endPage; i++) {
      if (!pagesToShow.contains(i)) {
        pagesToShow.add(i);
      }
    }

    if (endPage < maxPage) {
      if (endPage < maxPage - 1) {
        pagesToShow.add(-1);
      }
      if (!pagesToShow.contains(maxPage)) {
        pagesToShow.add(maxPage);
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: pagesToShow.map((page) {
        if (page == -1) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          );
        }

        final isCurrentPage = page == currentPage;
        final isCached = cachedPages.contains(page);

        return Material(
          color: isCurrentPage
              ? Theme.of(context).colorScheme.primary
              : isCached
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: page == currentPage ||
                    _state.isFetchingNextPage ||
                    _state.isFetchingPreviousPage
                ? null
                : () => _navigateToPage(page),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isCurrentPage
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: Text(
                '$page',
                style: TextStyle(
                  color: isCurrentPage
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight:
                      isCurrentPage ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPostsList() {
    final currentPagePosts = _currentPagePosts;
    final currentPage = _currentPage;
    final currentPageIndex = _state.pages.indexWhere(
      (page) => page.param == currentPage,
    );
    final currentPageData =
        currentPageIndex >= 0 ? _state.pages[currentPageIndex] : null;
    final hasError = currentPageData?.error != null;
    final isFetching =
        _state.isFetchingNextPage || _state.isFetchingPreviousPage;

    if (_state.pages.isEmpty) {
      if (_state.status == QueryStatus.loading || isFetching) {
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

    if (hasError && currentPageData != null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildErrorRetryCard(
          currentPageData.error!,
          currentPageIndex >= 0 ? currentPageIndex : null,
        ),
      );
    }

    if (isFetching && currentPagePosts.isEmpty) {
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
              Text('Loading page...'),
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
                  'Page $_currentPage - Posts (${currentPagePosts.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                if (isFetching) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: currentPagePosts.length,
              itemBuilder: (context, index) {
                final post = currentPagePosts[index];
                return _buildPostCard(post, currentPage);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post, int pageNumber) {
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
                    'Page $pageNumber',
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
}
