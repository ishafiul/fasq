import 'package:fasq/fasq.dart';
import 'package:fasq_example/services/models.dart';

class QueryKeys {
  static TypedQueryKey<List<User>> get users =>
      const TypedQueryKey<List<User>>('users', List<User>);

  static TypedQueryKey<User> user(Object id) =>
      TypedQueryKey<User>('user:$id', User);

  static TypedQueryKey<List<Post>> get posts =>
      const TypedQueryKey<List<Post>>('posts', List<Post>);

  static TypedQueryKey<List<Post>> postsByUser(Object userId) =>
      TypedQueryKey<List<Post>>('posts:user:$userId', List<Post>);

  static TypedQueryKey<Post> post(Object id) =>
      TypedQueryKey<Post>('post:$id', Post);

  static TypedQueryKey<List<Todo>> get todos =>
      const TypedQueryKey<List<Todo>>('todos', List<Todo>);

  static TypedQueryKey<List<Todo>> todosByUser(Object userId) =>
      TypedQueryKey<List<Todo>>('todos:user:$userId', List<Todo>);

  static TypedQueryKey<Todo> todo(Object id) =>
      TypedQueryKey<Todo>('todo:$id', Todo);

  static const TypedQueryKey<List<User>> prefetchUsers =
      TypedQueryKey<List<User>>('prefetch-users', List<User>);

  static const TypedQueryKey<List<Post>> prefetchPosts =
      TypedQueryKey<List<Post>>('prefetch-posts', List<Post>);

  static const TypedQueryKey<List<Todo>> prefetchTodos =
      TypedQueryKey<List<Todo>>('prefetch-todos', List<Todo>);

  static const TypedQueryKey<List<User>> usersStaleDemo =
      TypedQueryKey<List<User>>('users-stale-demo', List<User>);

  static const TypedQueryKey<List<Todo>> todosRefetchOnMountDemo =
      TypedQueryKey<List<Todo>>('todos-refetch-on-mount-demo', List<Todo>);

  static const TypedQueryKey<List<User>> usersEnabledDemo =
      TypedQueryKey<List<User>>('users-enabled-demo', List<User>);

  static const TypedQueryKey<List<User>> usersCallbacksDemo =
      TypedQueryKey<List<User>>('users-callbacks-demo', List<User>);

  static const TypedQueryKey<List<Post>> postsCacheDemo =
      TypedQueryKey<List<Post>>('posts-cache-demo', List<Post>);

  static TypedQueryKey<List<Category>> get categories =>
      const TypedQueryKey<List<Category>>('categories', List<Category>);

  static TypedQueryKey<List<Product>> productsByCategory(int categoryId) =>
      TypedQueryKey<List<Product>>('products:$categoryId', List<Product>);

  static const TypedQueryKey<User> regularUserProfile =
      TypedQueryKey<User>('user-regular', User);

  static const TypedQueryKey<User> secureUserProfile =
      TypedQueryKey<User>('user-secure', User);

  static const TypedQueryKey<User> userProfile =
      TypedQueryKey<User>('user-profile', User);

  static const TypedQueryKey<List<Todo>> userTodos =
      TypedQueryKey<List<Todo>>('user-todos', List<Todo>);

  static const TypedQueryKey<List<Post>> userPosts =
      TypedQueryKey<List<Post>>('user-posts', List<Post>);

  static const TypedQueryKey<List<Post>> postsInfiniteScroll =
      TypedQueryKey<List<Post>>('posts-infinite-scroll', List<Post>);

  static const TypedQueryKey<List<Post>> postsLoadMore =
      TypedQueryKey<List<Post>>('posts-load-more', List<Post>);

  static const TypedQueryKey<List<Post>> postsPageNumber =
      TypedQueryKey<List<Post>>('posts-page-number', List<Post>);

  static const TypedQueryKey<List<Post>> postsCursor =
      TypedQueryKey<List<Post>>('posts-cursor', List<Post>);
}
