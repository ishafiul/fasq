import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../query_keys.dart';

class BasicQueryClassScreen extends StatefulWidget {
  const BasicQueryClassScreen({super.key});

  @override
  State<BasicQueryClassScreen> createState() => _BasicQueryClassScreenState();
}

class _BasicQueryClassScreenState extends State<BasicQueryClassScreen> {
  late Query<List<User>> _query;
  int _referenceCount = 0;

  @override
  void initState() {
    super.initState();
    final client = context.queryClient ?? QueryClient();
    _query = client.getQuery<List<User>>(
      QueryKeys.users,
      () => ApiService.fetchUsers(),
      options: QueryOptions(
        staleTime: const Duration(seconds: 5),
        cacheTime: const Duration(seconds: 10),
      ),
    );
    _query.addListener();
    _referenceCount++;
  }

  @override
  void dispose() {
    _query.removeListener(); // Remove the initial listener
    _referenceCount--; // Decrement UI reference count to match
    // Don't dispose the query manually - let QueryClient handle it
    super.dispose();
  }

  void _addReference() {
    setState(() {
      _referenceCount++;
    });
    _query.addListener();
  }

  void _removeReference() {
    if (_referenceCount > 0) {
      setState(() {
        _referenceCount--;
      });
      _query.removeListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Basic Query - Query Class',
      description:
          'Demonstrates Query class usage with QueryClient, caching, and reference counting. Data is cached for 5 seconds.',
      codeSnippet: '''
class _BasicQueryClassScreenState extends State<BasicQueryClassScreen> {
  late Query<List<User>> _query;
  int _referenceCount = 0;

  @override
  void initState() {
    super.initState();
    final client = context.queryClient ?? QueryClient();
    _query = client.getQuery<List<User>>(
      QueryKeys.users,
      () => ApiService.fetchUsers(),
      options: QueryOptions(
        staleTime: const Duration(seconds: 5),
        cacheTime: const Duration(seconds: 10),
      ),
    );
    _query.addListener();
    _referenceCount++;
  }

  @override
  void dispose() {
    _query.removeListener();
    _referenceCount--;
    super.dispose();
  }

  void _addReference() {
    setState(() {
      _referenceCount++;
    });
    _query.addListener();
  }

  void _removeReference() {
    if (_referenceCount > 0) {
      setState(() {
        _referenceCount--;
      });
      _query.removeListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QueryState<List<User>>>(
      stream: _query.stream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _query.state;
        
        if (state.isLoading) {
          return LoadingWidget(message: 'Loading users...');
        }
        
        if (state.hasError) {
          return CustomErrorWidget(
            message: state.error.toString(),
            onRetry: () => _query.fetch(),
          );
        }
        
        if (state.hasData) {
          return Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('UI References: $_referenceCount'),
                      Text('Query References: ${_query.referenceCount}'),
                      ElevatedButton(
                        onPressed: _addReference,
                        child: const Text('Add Ref'),
                      ),
                      ElevatedButton(
                        onPressed: _removeReference,
                        child: const Text('Remove Ref'),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: state.data!.length,
                  itemBuilder: (context, index) {
                    final user = state.data![index];
                    return ListTile(
                      title: Text(user.name),
                      subtitle: Text(user.email),
                    );
                  },
                ),
              ),
            ],
          );
        }
        
        return const EmptyWidget(message: 'No users found');
      },
    );
  }
}''',
      child: StreamBuilder<QueryState<List<User>>>(
        stream: _query.stream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _query.state;

          if (state.isLoading) {
            return const LoadingWidget(message: 'Loading users...');
          }

          if (state.hasError) {
            return CustomErrorWidget(
              message: state.error.toString(),
              onRetry: () => _query.fetch(),
            );
          }

          if (state.hasData) {
            return Column(
              children: [
                // Reference count controls
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Reference Counting Demo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'UI References: $_referenceCount',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Query References: ${_query.referenceCount}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Query will be disposed when reference count reaches 0',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Data cached for 5 seconds (staleTime)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _addReference,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Ref'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _removeReference,
                              icon: const Icon(Icons.remove),
                              label: const Text('Remove Ref'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // User list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.data!.length,
                    itemBuilder: (context, index) {
                      final user = state.data![index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            child: Text(
                              user.name[0],
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(user.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email),
                              Text(
                                '@${user.username}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            'ID: ${user.id}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const EmptyWidget(message: 'No users found');
        },
      ),
    );
  }
}
