import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class InfiniteListCursorPage extends StatefulWidget {
  const InfiniteListCursorPage({super.key});

  @override
  State<InfiniteListCursorPage> createState() => _InfiniteListCursorPageState();
}

class _InfiniteListCursorPageState extends State<InfiniteListCursorPage> {
  late final InfiniteQuery<List<Map<String, dynamic>>, String> _query;
  late final CursorPagination<List<Map<String, dynamic>>, String> _pagination;

  @override
  void initState() {
    super.initState();
    _pagination = CursorPagination<List<Map<String, dynamic>>, String>(
      nextSelector: (page) =>
          page.isEmpty ? null : page.last['cursor'] as String?,
    );

    _query = QueryClient().getInfiniteQuery<List<Map<String, dynamic>>, String>(
      'example:cursor',
      (cursor) async {
        await Future.delayed(const Duration(milliseconds: 500));
        final start = int.tryParse(cursor) ?? 0;
        final data = List.generate(20, (i) {
          final id = start + i + 1;
          return {
            'id': id,
            'title': 'Post $id',
            'cursor': (start + 20).toString()
          };
        });
        return data;
      },
      options: InfiniteQueryOptions<List<Map<String, dynamic>>, String>(
        getNextPageParam: (pages, lastPage) =>
            _pagination.getNextPageParam(lastPage),
        maxPages: 10,
      ),
    );
    _query.addListener();
    // Kick off initial page with cursor '0'
    // ignore: discarded_futures
    _query.fetchNextPage('0');
  }

  @override
  void dispose() {
    _query.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Infinite List - Cursor')),
      body:
          StreamBuilder<InfiniteQueryState<List<Map<String, dynamic>>, String>>(
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

          return ListView.builder(
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
                      onPressed: () => _query.fetchNextPage(allItems.isEmpty
                          ? '0'
                          : allItems.last['cursor'] as String?),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load More'),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }

              final post = allItems[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(post['id'].toString())),
                  title: Text(post['title'] as String),
                  subtitle: Text('Cursor: ${post['cursor']}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
