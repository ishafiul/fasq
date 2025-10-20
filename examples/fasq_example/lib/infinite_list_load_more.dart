import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class InfiniteListLoadMorePage extends StatefulWidget {
  const InfiniteListLoadMorePage({super.key});

  @override
  State<InfiniteListLoadMorePage> createState() =>
      _InfiniteListLoadMorePageState();
}

class _InfiniteListLoadMorePageState extends State<InfiniteListLoadMorePage> {
  late final InfiniteQuery<List<String>, int> _query;

  @override
  void initState() {
    super.initState();
    _query = QueryClient().getInfiniteQuery<List<String>, int>(
      'example:load-more',
      (page) async {
        await Future.delayed(const Duration(milliseconds: 300));
        return List.generate(10, (i) => 'Item ${(page - 1) * 10 + i + 1}');
      },
      options: InfiniteQueryOptions<List<String>, int>(
        getNextPageParam: (pages, last) => pages.length + 1,
        maxPages: 5,
      ),
    );
    _query.addListener();
    // Load first page
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
      appBar: AppBar(title: const Text('Load More Button')),
      body: StreamBuilder<InfiniteQueryState<List<String>, int>>(
        stream: _query.stream,
        initialData: _query.state,
        builder: (context, snapshot) {
          final state = snapshot.data!;
          final all = state.pages
              .where((p) => p.data != null)
              .expand((p) => p.data!)
              .toList();
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (c, i) => ListTile(title: Text(all[i])),
                  separatorBuilder: (c, i) => const Divider(height: 0),
                  itemCount: all.length,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state.isFetchingNextPage
                        ? null
                        : () => _query.fetchNextPage(),
                    icon: state.isFetchingNextPage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download),
                    label: Text(
                        state.isFetchingNextPage ? 'Loading...' : 'Load More'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
