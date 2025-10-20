import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class InfiniteListPageNumberPage extends StatefulWidget {
  const InfiniteListPageNumberPage({super.key});

  @override
  State<InfiniteListPageNumberPage> createState() =>
      _InfiniteListPageNumberPageState();
}

class _InfiniteListPageNumberPageState
    extends State<InfiniteListPageNumberPage> {
  late final InfiniteQuery<List<int>, int> _query;
  late final PageNumberPagination<List<int>> _pagination;
  late final InfiniteQueryOptions<List<int>, int> _options;

  @override
  void initState() {
    super.initState();
    _pagination = const PageNumberPagination<List<int>>(
        startAt: 1, pageSize: 20, hasPrevious: false);
    _options = InfiniteQueryOptions<List<int>, int>(
      getNextPageParam: (pages, lastPage) =>
          _pagination.getNextPageParam(lastPage, pages.length),
      maxPages: 10,
    );
    _query = QueryClient().getInfiniteQuery<List<int>, int>(
      'example:page-number',
      (page) async {
        await Future.delayed(const Duration(milliseconds: 400));
        return List<int>.generate(20, (i) => (page - 1) * 20 + i + 1);
      },
      options: _options,
    );
    _query.addListener();
    // Kick off initial page load
    // Start at page 1 for page-number pagination
    // ignore: discarded_futures
    _query.fetchNextPage(1);
  }

  @override
  void dispose() {
    _query.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite List - Page Number'),
      ),
      body: StreamBuilder<InfiniteQueryState<List<int>, int>>(
        stream: _query.stream,
        initialData: _query.state,
        builder: (context, snapshot) {
          final state = snapshot.data!;
          final allItems = state.pages
              .where((p) => p.data != null)
              .expand((p) => p.data!)
              .toList();

          if (state.status == QueryStatus.loading && allItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                if (state.hasNextPage && !state.isFetchingNextPage) {
                  _query.fetchNextPage();
                }
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: allItems.length + 1,
              itemBuilder: (context, index) {
                if (index == allItems.length) {
                  if (state.isFetchingNextPage) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (state.hasNextPage) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton.icon(
                        onPressed: () => _query.fetchNextPage(),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load More'),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }

                final value = allItems[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(value.toString())),
                    title: Text('Item #$value'),
                    subtitle: Text('Page item index ${index + 1}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
