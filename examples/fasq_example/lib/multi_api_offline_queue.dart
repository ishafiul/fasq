import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';

// Example API service
class ApiService {
  static Future<String> createPost(String content) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Created post: $content';
  }

  static Future<String> updateUser(String userId, String name) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'Updated user $userId: $name';
  }

  static Future<String> deleteComment(String commentId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return 'Deleted comment: $commentId';
  }

  static Future<String> likePost(String postId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return 'Liked post: $postId';
  }
}

class MultiApiOfflineQueuePage extends StatefulWidget {
  const MultiApiOfflineQueuePage({super.key});

  @override
  State<MultiApiOfflineQueuePage> createState() =>
      _MultiApiOfflineQueuePageState();
}

class _MultiApiOfflineQueuePageState extends State<MultiApiOfflineQueuePage> {
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  bool _isOffline = false;
  final List<String> _actions = [];

  @override
  void initState() {
    super.initState();
    _registerMutationTypes();
  }

  void _registerMutationTypes() {
    // Register different mutation types for offline processing
    MutationTypeRegistry.register<String, String>(
      'createPost',
      (String content) => ApiService.createPost(content),
    );

    MutationTypeRegistry.register<String, Map<String, String>>(
      'updateUser',
      (Map<String, String> data) => ApiService.updateUser(
        data['userId']!,
        data['name']!,
      ),
    );

    MutationTypeRegistry.register<String, String>(
      'deleteComment',
      (String commentId) => ApiService.deleteComment(commentId),
    );

    MutationTypeRegistry.register<String, String>(
      'likePost',
      (String postId) => ApiService.likePost(postId),
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    _userController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _toggleOffline() {
    setState(() {
      _isOffline = !_isOffline;
    });
    NetworkStatus.instance.setOnline(!_isOffline);

    // Process queue when coming back online
    if (!_isOffline) {
      _processQueue();
    }
  }

  void _processQueue() async {
    final queueManager = OfflineQueueManager.instance;
    if (queueManager.length > 0) {
      await queueManager.processQueue();
      _refreshActions();
    }
  }

  void _refreshActions() {
    setState(() {});
  }

  void _createPost() {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    final mutation = Mutation<String, String>(
      mutationFn: (String content) => ApiService.createPost(content),
      options: MutationOptions(
        queueWhenOffline: true,
        priority: 1, // Lower priority
        onQueued: (variables) {
          setState(() {
            _actions.add('Queued: Create post "$variables"');
          });
        },
        onSuccess: (result) {
          setState(() {
            _actions.add('Success: $result');
          });
        },
      ),
    );

    mutation.mutate(content);
    _postController.clear();
  }

  void _updateUser() {
    final name = _userController.text.trim();
    if (name.isEmpty) return;

    final mutation = Mutation<String, Map<String, String>>(
      mutationFn: (Map<String, String> data) => ApiService.updateUser(
        data['userId']!,
        data['name']!,
      ),
      options: MutationOptions(
        queueWhenOffline: true,
        priority: 3, // Higher priority
        onQueued: (variables) {
          setState(() {
            _actions.add('Queued: Update user "${variables['name']}"');
          });
        },
        onSuccess: (result) {
          setState(() {
            _actions.add('Success: $result');
          });
        },
      ),
    );

    mutation.mutate({'userId': 'user123', 'name': name});
    _userController.clear();
  }

  void _deleteComment() {
    final commentId = _commentController.text.trim();
    if (commentId.isEmpty) return;

    final mutation = Mutation<String, String>(
      mutationFn: (String commentId) => ApiService.deleteComment(commentId),
      options: MutationOptions(
        queueWhenOffline: true,
        priority: 2, // Medium priority
        onQueued: (variables) {
          setState(() {
            _actions.add('Queued: Delete comment "$variables"');
          });
        },
        onSuccess: (result) {
          setState(() {
            _actions.add('Success: $result');
          });
        },
      ),
    );

    mutation.mutate(commentId);
    _commentController.clear();
  }

  void _likePost() {
    final mutation = Mutation<String, String>(
      mutationFn: (String postId) => ApiService.likePost(postId),
      options: MutationOptions(
        queueWhenOffline: true,
        priority: 4, // Highest priority
        onQueued: (variables) {
          setState(() {
            _actions.add('Queued: Like post "$variables"');
          });
        },
        onSuccess: (result) {
          setState(() {
            _actions.add('Success: $result');
          });
        },
      ),
    );

    mutation.mutate('post456');
  }

  @override
  Widget build(BuildContext context) {
    final queueStats = OfflineQueueManager.instance.getQueueStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-API Offline Queue'),
        actions: [
          if (OfflineQueueManager.instance.length > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Badge(
                label: Text('${OfflineQueueManager.instance.length}'),
                child: const Icon(Icons.queue),
              ),
            ),
          Switch(
            value: _isOffline,
            onChanged: (_) => _toggleOffline(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Network Status
          Container(
            padding: const EdgeInsets.all(16),
            color: _isOffline ? Colors.red.shade100 : Colors.green.shade100,
            child: Row(
              children: [
                Icon(
                  _isOffline ? Icons.wifi_off : Icons.wifi,
                  color: _isOffline ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOffline ? 'Offline Mode' : 'Online Mode',
                  style: TextStyle(
                    color: _isOffline ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Queue Statistics
          if (queueStats.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Queue Statistics:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...queueStats.entries.map((entry) {
                    return Text('${entry.key}: ${entry.value} pending');
                  }),
                ],
              ),
            ),

          // Action Forms
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Create Post
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Create Post (Priority: 1)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _postController,
                            decoration: const InputDecoration(
                              hintText: 'Post content...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _createPost,
                            child: const Text('Create Post'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Update User
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Update User (Priority: 3)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _userController,
                            decoration: const InputDecoration(
                              hintText: 'New name...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _updateUser,
                            child: const Text('Update User'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Delete Comment
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delete Comment (Priority: 2)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Comment ID...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _deleteComment,
                            child: const Text('Delete Comment'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Like Post
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Like Post (Priority: 4)',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _likePost,
                            child: const Text('Like Post'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actions Log
                  const Text('Actions Log:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._actions.reversed.take(10).map((action) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(action, style: const TextStyle(fontSize: 12)),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
