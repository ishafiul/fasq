/// Exception thrown when persistence operations fail.
class PersistenceException implements Exception {
  final String message;
  const PersistenceException(this.message);

  @override
  String toString() => 'PersistenceException: $message';
}

