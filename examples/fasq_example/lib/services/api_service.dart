import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String _baseUrl = 'https://jsonplaceholder.typicode.com';
  static const bool _useMockApi = true; // Toggle between mock and real API

  static final Random _random = Random();

  // Mock data
  static final List<User> _mockUsers = List.generate(
      10,
      (index) => User(
            id: index + 1,
            name: 'User ${index + 1}',
            email: 'user${index + 1}@example.com',
            username: 'user${index + 1}',
            phone: '+1-555-${(1000 + index).toString()}',
            website: 'user${index + 1}.com',
          ));

  static final List<Post> _mockPosts = List.generate(
      50,
      (index) => Post(
            id: index + 1,
            userId: (index % 10) + 1,
            title: 'Post ${index + 1}',
            body:
                'This is the body of post ${index + 1}. It contains some sample content to demonstrate the functionality.',
          ));

  static final List<Todo> _mockTodos = List.generate(
      20,
      (index) => Todo(
            id: index + 1,
            userId: (index % 10) + 1,
            title: 'Todo ${index + 1}',
            completed: index % 3 == 0,
          ));

  static final List<Comment> _mockComments = List.generate(
      30,
      (index) => Comment(
            id: index + 1,
            postId: (index % 10) + 1,
            name: 'Commenter ${index + 1}',
            email: 'commenter${index + 1}@example.com',
            body: 'This is comment ${index + 1} on the post.',
          ));

  static final List<Category> _mockCategories = List.generate(
      5,
      (index) => Category(
            id: index + 1,
            name: 'Category ${index + 1}',
            description: 'Description for Category ${index + 1}',
          ));

  static final List<Product> _mockProducts = List.generate(
      20,
      (index) => Product(
            id: index + 1,
            name: 'Product ${index + 1}',
            description: 'Description for Product ${index + 1}',
            price: (10.0 + index * 5.0),
            categoryId: (index % 5) + 1,
          ));

  // Simulate network delay
  static Future<void> _simulateDelay() async {
    if (_useMockApi) {
      await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(1000)));
    }
  }

  // Simulate network errors
  static bool _shouldSimulateError() {
    if (_useMockApi) {
      return _random.nextDouble() < 0.1; // 10% chance of error
    }
    return false;
  }

  // Users API
  static Future<List<User>> fetchUsers() async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch users');
    }

    if (_useMockApi) {
      return List.from(_mockUsers);
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/users'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch users: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  static Future<User> fetchUser(int id) async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch user $id');
    }

    if (_useMockApi) {
      final user = _mockUsers.firstWhere((u) => u.id == id);
      return user;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/users/$id'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return User.fromJson(json);
      } else {
        throw Exception('Failed to fetch user: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  // Posts API
  static Future<List<Post>> fetchPosts() async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch posts');
    }

    if (_useMockApi) {
      return List.from(_mockPosts);
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/posts'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Post.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch posts: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to fetch posts: $e');
    }
  }

  static Future<List<Post>> fetchUserPosts(int userId) async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch posts for user $userId');
    }

    if (_useMockApi) {
      return _mockPosts.where((p) => p.userId == userId).toList();
    }

    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/posts?userId=$userId'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Post.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch user posts: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to fetch user posts: $e');
    }
  }

  static Future<List<Post>> fetchPostsPaginated(int page,
      {int limit = 10}) async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch posts page $page');
    }

    if (_useMockApi) {
      final startIndex = (page - 1) * limit;
      final endIndex = startIndex + limit;
      if (startIndex >= _mockPosts.length) {
        return [];
      }
      return _mockPosts.sublist(
          startIndex, endIndex.clamp(0, _mockPosts.length));
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/posts?_page=$page&_limit=$limit'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Post.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch posts page: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to fetch posts page: $e');
    }
  }

  // Todos API
  static Future<List<Todo>> fetchTodos() async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch todos');
    }

    if (_useMockApi) {
      return List.from(_mockTodos);
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/todos'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Todo.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch todos: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to fetch todos: $e');
    }
  }

  static Future<Todo> createTodo(CreateTodoRequest request) async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to create todo');
    }

    if (_useMockApi) {
      final newTodo = Todo(
        id: _mockTodos.length + 1,
        userId: request.userId,
        title: request.title,
        completed: request.completed,
      );
      _mockTodos.add(newTodo);
      return newTodo;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/todos'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );
      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Todo.fromJson(json);
      } else {
        throw Exception('Failed to create todo: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to create todo: $e');
    }
  }

  static Future<Todo> updateTodo(int id, Todo updatedTodo) async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to update todo $id');
    }

    if (_useMockApi) {
      final index = _mockTodos.indexWhere((t) => t.id == id);
      if (index != -1) {
        _mockTodos[index] = updatedTodo;
        return updatedTodo;
      }
      throw Exception('Todo not found');
    }

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/todos/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updatedTodo.toJson()),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Todo.fromJson(json);
      } else {
        throw Exception('Failed to update todo: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to update todo: $e');
    }
  }

  // Comments API
  static Future<List<Comment>> fetchComments(int postId) async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch comments for post $postId');
    }

    if (_useMockApi) {
      return _mockComments.where((c) => c.postId == postId).toList();
    }

    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/comments?postId=$postId'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Comment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch comments: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  // Categories API
  static Future<List<Category>> fetchCategories() async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch categories');
    }

    if (_useMockApi) {
      return List.from(_mockCategories);
    }

    try {
      // Note: JSONPlaceholder doesn't have categories endpoint
      // This is a placeholder for a real API implementation
      throw Exception('Categories API not implemented for real API');
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // Products API
  static Future<List<Product>> fetchProducts(int categoryId) async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception('Failed to fetch products for category $categoryId');
    }

    if (_useMockApi) {
      return _mockProducts.where((p) => p.categoryId == categoryId).toList();
    }

    try {
      // Note: JSONPlaceholder doesn't have products endpoint
      // This is a placeholder for a real API implementation
      throw Exception('Products API not implemented for real API');
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  // Utility methods
  static String get apiMode => _useMockApi ? 'Mock API' : 'Real API';

  static bool get isUsingMockApi => _useMockApi;

  static void toggleApiMode() {
    // This would require restarting the app to take effect
    // In a real app, you might use SharedPreferences or similar
  }
}
