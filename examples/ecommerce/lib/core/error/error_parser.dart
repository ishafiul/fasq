import 'package:dio/dio.dart';

/// Abstract interface for parsing errors from API responses.
///
/// Implement this interface to create custom error parsers for different
/// backend error response formats. The parser is used by [ErrorInterceptor]
/// to automatically transform DioExceptions into user-friendly error messages.
///
/// Example implementation:
/// ```dart
/// class MyCustomErrorParser extends ErrorParser {
///   const MyCustomErrorParser();
///
///   @override
///   String parse(DioException exception) {
///     final data = exception.response?.data;
///     if (data is Map<String, dynamic>) {
///       return data['error_message'] ?? 'Unknown error';
///     }
///     return exception.message ?? 'Unknown error';
///   }
/// }
/// ```
abstract class ErrorParser {
  /// Creates an error parser.
  const ErrorParser();

  /// Parses a [DioException] and returns a clean, user-friendly error message.
  ///
  /// This method should:
  /// - Extract error messages from the response data
  /// - Handle various response structures
  /// - Provide meaningful fallback messages
  /// - Return a single string message for display to users
  String parse(DioException exception);
}
