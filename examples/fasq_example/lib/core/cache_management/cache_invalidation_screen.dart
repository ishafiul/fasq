import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class CacheInvalidationScreen extends StatefulWidget {
  const CacheInvalidationScreen({super.key});

  @override
  State<CacheInvalidationScreen> createState() =>
      _CacheInvalidationScreenState();
}

class _CacheInvalidationScreenState extends State<CacheInvalidationScreen> {
  late QueryClient _queryClient;
  late Query<User> _userQuery;
  late Query<List<Todo>> _todosQuery;
  late Query<List<Post>> _postsQuery;
  StreamSubscription? _userSubscription;
  StreamSubscription? _todosSubscription;
  StreamSubscription? _postsSubscription;

  User? _userData;
  List<Todo> _todosData = [];
  List<Post> _postsData = [];

  bool _userLoading = false;
  bool _todosLoading = false;
  bool _postsLoading = false;

  @override
  void initState() {
    super.initState();
    _queryClient = QueryClient();
    _initializeQueries();
  }

  void _initializeQueries() {
    // User Query
    _userQuery = Query<User>(
      key: 'user-profile',
      queryFn: () => ApiService.fetchUser(1),
      cache: _queryClient.cache,
    );

    _userSubscription = _userQuery.stream.listen((state) {
      if (mounted) {
        setState(() {
          _userData = state.data;
          _userLoading = state.isLoading;
        });
      }
    });

    // Todos Query
    _todosQuery = Query<List<Todo>>(
      key: 'user-todos',
      queryFn: ApiService.fetchTodos,
      cache: _queryClient.cache,
    );

    _todosSubscription = _todosQuery.stream.listen((state) {
      if (mounted) {
        setState(() {
          _todosData = state.data ?? [];
          _todosLoading = state.isLoading;
        });
      }
    });

    // Posts Query
    _postsQuery = Query<List<Post>>(
      key: 'user-posts',
      queryFn: ApiService.fetchPosts,
      cache: _queryClient.cache,
    );

    _postsSubscription = _postsQuery.stream.listen((state) {
      if (mounted) {
        setState(() {
          _postsData = state.data ?? [];
          _postsLoading = state.isLoading;
        });
      }
    });

    // Initial fetch
    _userQuery.fetch();
    _todosQuery.fetch();
    _postsQuery.fetch();
  }

  void _invalidateUser() {
    _queryClient.invalidateQuery('user-profile');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Invalidated user query - refetching...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _invalidateTodos() {
    _queryClient.invalidateQuery('user-todos');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Invalidated todos query - refetching...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _invalidatePosts() {
    _queryClient.invalidateQuery('user-posts');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Invalidated posts query - refetching...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _invalidateAll() {
    _queryClient
        .invalidateQueries(['user-profile', 'user-todos', 'user-posts']);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Invalidated all queries - refetching...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _invalidateWithPrefix() {
    // Invalidate all queries starting with 'user-'
    _queryClient.invalidateQueriesWithPrefix('user-');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Invalidated all queries with prefix "user-"'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _invalidateWhere() {
    // Invalidate queries with 'todo' or 'post' in the key
    _queryClient.invalidateQueriesWhere(
        (key) => key.contains('todo') || key.contains('post'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Invalidated matching queries (todos & posts)'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _todosSubscription?.cancel();
    _postsSubscription?.cancel();
    _userQuery.dispose();
    _todosQuery.dispose();
    _postsQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Cache Invalidation',
      description:
          'Demonstrates cache invalidation strategies. Invalidate specific queries, multiple queries, or queries matching patterns. Invalidated queries are automatically refetched if they are active.',
      codeSnippet: '''
// Invalidate a single query
queryClient.invalidateQuery('user-profile');

// Invalidate multiple queries at once
queryClient.invalidateQueries([
  'user-profile',
  'user-todos',
  'user-posts',
]);

// Invalidate all queries with a prefix
queryClient.invalidateQueriesWithPrefix('user-');

// Invalidate queries matching a condition
queryClient.invalidateQueriesWhere((key) => 
  key.contains('todo') || key.contains('post')
);

// Behavior:
// - Removes cache entry
// - Active queries automatically refetch
// - Inactive queries refetch on next access
// - Useful for manual cache management after mutations
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
                  _buildQueriesDisplay(),
                  const SizedBox(height: 24),
                  _buildInvalidationButtons(),
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
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Cache Invalidation Strategies:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1️⃣ Invalidate Single Query - force refetch of specific query\n'
            '2️⃣ Invalidate Multiple - invalidate several queries at once\n'
            '3️⃣ Invalidate With Prefix - batch invalidate by key prefix\n'
            '4️⃣ Invalidate Where - invalidate using pattern matching\n'
            '5️⃣ Watch queries refetch automatically after invalidation\n'
            '6️⃣ Active queries refetch immediately, others on next access',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildQueriesDisplay() {
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
            'Current Queries',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // User Query
          _buildQueryCard(
            'User Profile',
            _userData?.name ?? 'Loading...',
            _userLoading,
            Colors.blue,
          ),
          const SizedBox(height: 12),

          // Todos Query
          _buildQueryCard(
            'Todos',
            '${_todosData.length} items',
            _todosLoading,
            Colors.green,
          ),
          const SizedBox(height: 12),

          // Posts Query
          _buildQueryCard(
            'Posts',
            '${_postsData.length} items',
            _postsLoading,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildQueryCard(
      String title, String content, bool loading, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 16,
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvalidationButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invalidation Methods',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        // Single Invalidation
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _invalidateUser,
              icon: const Icon(Icons.person),
              label: const Text('Invalidate User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _invalidateTodos,
              icon: const Icon(Icons.list),
              label: const Text('Invalidate Todos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _invalidatePosts,
              icon: const Icon(Icons.article),
              label: const Text('Invalidate Posts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // Batch Invalidation
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _invalidateAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Invalidate All Queries'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _invalidateWithPrefix,
            icon: const Icon(Icons.tag),
            label: const Text('Invalidate With Prefix "user-"'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _invalidateWhere,
            icon: const Icon(Icons.filter_list),
            label: const Text('Invalidate Where (todos or posts)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
