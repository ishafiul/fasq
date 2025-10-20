import 'dart:convert';

import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DependentQueriesUserPostsPage extends StatelessWidget {
  const DependentQueriesUserPostsPage({super.key});

  Future<Map<String, dynamic>> fetchUser() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final res = await http
        .get(Uri.parse('https://jsonplaceholder.typicode.com/users/1'));
    if (res.statusCode != 200) throw Exception('user fetch failed');
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchPosts(int userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final res = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts?userId=$userId'));
    if (res.statusCode != 200) throw Exception('posts fetch failed');
    return json.decode(res.body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dependent Queries: User → Posts')),
      body: Column(
        children: [
          Expanded(
            child: QueryBuilder<Map<String, dynamic>>(
              queryKey: 'user:1',
              queryFn: fetchUser,
              builder: (context, userState) {
                if (userState.isLoading && !userState.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (userState.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('User error: ${userState.error}'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () =>
                              QueryClient().invalidateQuery('user:1'),
                          child: const Text('Retry user'),
                        ),
                      ],
                    ),
                  );
                }

                final user = userState.data;
                final postsKey = 'posts:user:${user?['id']}';
                final enabled = userState.isSuccess && user?['id'] != null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('User: ${user['name']} (${user['id']})',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    Expanded(
                      child: QueryBuilder<List<dynamic>>(
                        queryKey: postsKey,
                        queryFn: () => fetchPosts(user!['id'] as int),
                        options: QueryOptions(enabled: enabled),
                        builder: (context, postsState) {
                          if (!enabled) {
                            return const Center(
                                child: Text('Waiting for user...'));
                          }
                          if (postsState.isLoading && !postsState.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (postsState.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 48, color: Colors.red),
                                  const SizedBox(height: 8),
                                  Text('Posts error: ${postsState.error}'),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () =>
                                        QueryClient().invalidateQuery(postsKey),
                                    child: const Text('Retry posts'),
                                  ),
                                ],
                              ),
                            );
                          }

                          final posts = postsState.data ?? const [];
                          return ListView.separated(
                            padding: const EdgeInsets.all(8),
                            separatorBuilder: (_, __) =>
                                const Divider(height: 0),
                            itemCount: posts.length,
                            itemBuilder: (_, i) => ListTile(
                              leading: CircleAvatar(
                                  child: Text('${posts[i]['id']}')),
                              title: Text(posts[i]['title'] as String),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

