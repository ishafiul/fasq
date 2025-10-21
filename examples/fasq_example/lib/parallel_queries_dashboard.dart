import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';

// Mock API service
class ApiService {
  static Future<List<User>> fetchUsers() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      User(id: 1, name: 'John Doe', email: 'john@example.com'),
      User(id: 2, name: 'Jane Smith', email: 'jane@example.com'),
      User(id: 3, name: 'Bob Johnson', email: 'bob@example.com'),
    ];
  }

  static Future<List<Post>> fetchPosts() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      Post(
          id: 1,
          title: 'First Post',
          content: 'This is the first post',
          userId: 1),
      Post(
          id: 2,
          title: 'Second Post',
          content: 'This is the second post',
          userId: 2),
      Post(
          id: 3,
          title: 'Third Post',
          content: 'This is the third post',
          userId: 1),
    ];
  }

  static Future<List<Comment>> fetchComments() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      Comment(id: 1, content: 'Great post!', postId: 1, userId: 2),
      Comment(id: 2, content: 'Thanks for sharing', postId: 1, userId: 3),
      Comment(id: 3, content: 'Very informative', postId: 2, userId: 1),
    ];
  }
}

// Data models
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});
}

class Post {
  final int id;
  final String title;
  final String content;
  final int userId;

  Post(
      {required this.id,
      required this.title,
      required this.content,
      required this.userId});
}

class Comment {
  final int id;
  final String content;
  final int postId;
  final int userId;

  Comment(
      {required this.id,
      required this.content,
      required this.postId,
      required this.userId});
}

// Error banner widget
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Some queries failed to load. Please try again.',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

// Section widgets
class UsersSection extends StatelessWidget {
  final QueryState<List<User>> state;

  const UsersSection(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Users (${state.isLoading ? 'Loading...' : state.hasData ? state.data!.length.toString() : 'Error'})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (state.isLoading)
              const LinearProgressIndicator()
            else if (state.hasError)
              Text('Error: ${state.error}',
                  style: const TextStyle(color: Colors.red))
            else if (state.hasData)
              ...state.data!.map((user) => ListTile(
                    leading: CircleAvatar(child: Text(user.name[0])),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                  ))
            else
              const Text('No data'),
          ],
        ),
      ),
    );
  }
}

class PostsSection extends StatelessWidget {
  final QueryState<List<Post>> state;

  const PostsSection(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Posts (${state.isLoading ? 'Loading...' : state.hasData ? state.data!.length.toString() : 'Error'})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (state.isLoading)
              const LinearProgressIndicator()
            else if (state.hasError)
              Text('Error: ${state.error}',
                  style: const TextStyle(color: Colors.red))
            else if (state.hasData)
              ...state.data!.map((post) => ListTile(
                    leading: const Icon(Icons.article),
                    title: Text(post.title),
                    subtitle: Text(post.content),
                  ))
            else
              const Text('No data'),
          ],
        ),
      ),
    );
  }
}

class CommentsSection extends StatelessWidget {
  final QueryState<List<Comment>> state;

  const CommentsSection(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments (${state.isLoading ? 'Loading...' : state.hasData ? state.data!.length.toString() : 'Error'})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (state.isLoading)
              const LinearProgressIndicator()
            else if (state.hasError)
              Text('Error: ${state.error}',
                  style: const TextStyle(color: Colors.red))
            else if (state.hasData)
              ...state.data!.map((comment) => ListTile(
                    leading: const Icon(Icons.comment),
                    title: Text(comment.content),
                    subtitle: Text('Post ID: ${comment.postId}'),
                  ))
            else
              const Text('No data'),
          ],
        ),
      ),
    );
  }
}

// Core package example using QueryBuilder
class ParallelQueriesDashboardCore extends StatelessWidget {
  const ParallelQueriesDashboardCore({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard (Core)'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This dashboard demonstrates parallel queries using the core package. '
              'All three data sources (users, posts, comments) load independently '
              'and update the UI as they complete.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  QueryBuilder<List<User>>(
                    queryKey: 'users',
                    queryFn: () => ApiService.fetchUsers(),
                    builder: (context, state) => UsersSection(state),
                  ),
                  QueryBuilder<List<Post>>(
                    queryKey: 'posts',
                    queryFn: () => ApiService.fetchPosts(),
                    builder: (context, state) => PostsSection(state),
                  ),
                  QueryBuilder<List<Comment>>(
                    queryKey: 'comments',
                    queryFn: () => ApiService.fetchComments(),
                    builder: (context, state) => CommentsSection(state),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Hooks example
class ParallelQueriesDashboardHooks extends StatelessWidget {
  const ParallelQueriesDashboardHooks({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard (Hooks)'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Hooks adapter not available in this example.\n'
          'Use the core package example instead.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Bloc example
class ParallelQueriesDashboardBloc extends StatelessWidget {
  const ParallelQueriesDashboardBloc({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard (Bloc)'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Bloc adapter not available in this example.\n'
          'Use the core package example instead.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Riverpod example
class ParallelQueriesDashboardRiverpod extends StatelessWidget {
  const ParallelQueriesDashboardRiverpod({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard (Riverpod)'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Riverpod adapter not available in this example.\n'
          'Use the core package example instead.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Main page with tabs
class ParallelQueriesDashboardPage extends StatefulWidget {
  const ParallelQueriesDashboardPage({super.key});

  @override
  State<ParallelQueriesDashboardPage> createState() =>
      _ParallelQueriesDashboardPageState();
}

class _ParallelQueriesDashboardPageState
    extends State<ParallelQueriesDashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ParallelQueriesDashboardCore(),
    const ParallelQueriesDashboardHooks(),
    const ParallelQueriesDashboardBloc(),
    const ParallelQueriesDashboardRiverpod(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parallel Queries Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'This dashboard demonstrates parallel queries across all three adapters. '
              'Notice how all three data sources (users, posts, comments) load independently '
              'and update the UI as they complete.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Core',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.link),
            label: 'Hooks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_module),
            label: 'Bloc',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree),
            label: 'Riverpod',
          ),
        ],
      ),
    );
  }
}
