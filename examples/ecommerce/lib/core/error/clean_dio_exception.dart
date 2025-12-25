import 'package:dio/dio.dart';

/// A custom DioException that returns clean error messages in toString().
///
/// This exception extends [DioException] and overrides [toString()] to return
/// only the error message without the DioException type prefix, making it
/// suitable for direct display to users.
class CleanDioException extends DioException {
  final String _cleanMessage;

  /// Creates a clean DioException.
  ///
  /// [requestOptions] is the original request options.
  /// [response] is the response if available.
  /// [type] is the exception type.
  /// [error] is the original error object.
  /// [cleanMessage] is the user-friendly error message.
  /// [stackTrace] is the stack trace.
  CleanDioException({
    required super.requestOptions,
    super.response,
    super.type = DioExceptionType.unknown,
    super.error,
    required String cleanMessage,
    super.stackTrace,
  }) : _cleanMessage = cleanMessage;

  /// Creates a CleanDioException from an existing DioException.
  ///
  /// [original] is the original DioException.
  /// [cleanMessage] is the user-friendly error message.
  factory CleanDioException.from(DioException original, String cleanMessage) {
    return CleanDioException(
      requestOptions: original.requestOptions,
      response: original.response,
      type: original.type,
      error: original.error,
      cleanMessage: cleanMessage,
      stackTrace: original.stackTrace,
    );
  }

  @override
  String toString() => _cleanMessage;

  @override
  String? get message => _cleanMessage;
}
