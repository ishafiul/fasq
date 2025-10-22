class User {
  final int id;
  final String name;
  final String email;
  final String username;
  final String phone;
  final String website;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.phone,
    required this.website,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      phone: json['phone'] as String,
      website: json['website'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'phone': phone,
      'website': website,
    };
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.username == username &&
        other.phone == phone &&
        other.website == website;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, email, username, phone, website);
  }
}

class Post {
  final int id;
  final int userId;
  final String title;
  final String body;

  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
    };
  }

  @override
  String toString() {
    return 'Post(id: $id, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Post &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.body == body;
  }

  @override
  int get hashCode {
    return Object.hash(id, userId, title, body);
  }
}

class Todo {
  final int id;
  final int userId;
  final String title;
  final bool completed;

  const Todo({
    required this.id,
    required this.userId,
    required this.title,
    required this.completed,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      completed: json['completed'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'completed': completed,
    };
  }

  Todo copyWith({
    int? id,
    int? userId,
    String? title,
    bool? completed,
  }) {
    return Todo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, completed: $completed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.completed == completed;
  }

  @override
  int get hashCode {
    return Object.hash(id, userId, title, completed);
  }
}

class Comment {
  final int id;
  final int postId;
  final String name;
  final String email;
  final String body;

  const Comment({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      postId: json['postId'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      body: json['body'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'name': name,
      'email': email,
      'body': body,
    };
  }

  @override
  String toString() {
    return 'Comment(id: $id, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Comment &&
        other.id == id &&
        other.postId == postId &&
        other.name == name &&
        other.email == email &&
        other.body == body;
  }

  @override
  int get hashCode {
    return Object.hash(id, postId, name, email, body);
  }
}

class CreateTodoRequest {
  final int userId;
  final String title;
  final bool completed;

  const CreateTodoRequest({
    required this.userId,
    required this.title,
    this.completed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'completed': completed,
    };
  }
}

class UpdateUserRequest {
  final String name;
  final String email;
  final String phone;
  final String website;

  const UpdateUserRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.website,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'website': website,
    };
  }
}
