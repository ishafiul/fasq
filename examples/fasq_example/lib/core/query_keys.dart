import 'package:fasq/fasq.dart';

class User {
  final String id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

class Post {
  final String id;
  final String title;
  final String body;
  final String userId;

  Post({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      userId: json['userId'] as String,
    );
  }
}

class Todo {
  final String id;
  final String title;
  final bool completed;
  final String userId;

  Todo({
    required this.id,
    required this.title,
    required this.completed,
    required this.userId,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool,
      userId: json['userId'] as String,
    );
  }
}

class QueryKeys {
  static TypedQueryKey<List<User>> get users =>
      const TypedQueryKey<List<User>>('users', List<User>);

  static TypedQueryKey<User> user(String id) =>
      TypedQueryKey<User>('user:$id', User);

  static TypedQueryKey<List<Post>> get posts =>
      const TypedQueryKey<List<Post>>('posts', List<Post>);

  static TypedQueryKey<List<Post>> postsByUser(String userId) =>
      TypedQueryKey<List<Post>>('posts:user:$userId', List<Post>);

  static TypedQueryKey<Post> post(String id) =>
      TypedQueryKey<Post>('post:$id', Post);

  static TypedQueryKey<List<Todo>> get todos =>
      const TypedQueryKey<List<Todo>>('todos', List<Todo>);

  static TypedQueryKey<List<Todo>> todosByUser(String userId) =>
      TypedQueryKey<List<Todo>>('todos:user:$userId', List<Todo>);

  static TypedQueryKey<Todo> todo(String id) =>
      TypedQueryKey<Todo>('todo:$id', Todo);

  static const TypedQueryKey<List<User>> prefetchUsers =
      TypedQueryKey<List<User>>('prefetch-users', List<User>);

  static const TypedQueryKey<List<Post>> prefetchPosts =
      TypedQueryKey<List<Post>>('prefetch-posts', List<Post>);

  static const TypedQueryKey<List<Todo>> prefetchTodos =
      TypedQueryKey<List<Todo>>('prefetch-todos', List<Todo>);
}


