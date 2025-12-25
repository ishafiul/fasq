import 'package:dio/dio.dart';
import 'package:ecommerce/core/error/clean_dio_exception.dart';
import 'package:ecommerce/core/error/error_parser.dart';
import 'package:ecommerce/core/utils/logger.dart';

/// Dio interceptor that automatically transforms API errors into clean messages.
///
/// This interceptor uses an [ErrorParser] to extract user-friendly error messages
/// from DioExceptions. It wraps the exception in a [CleanDioException] that
/// returns only the clean message when [toString()] is called.
///
/// Usage:
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(ErrorInterceptor(DefaultErrorParser()));
/// ```
class ErrorInterceptor extends Interceptor {
  final ErrorParser _parser;

  /// Creates an error interceptor with the specified [parser].
  ErrorInterceptor(this._parser);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final originalMessage = err.message;
    final cleanMessage = _parser.parse(err);

    logger.e(
      'ErrorInterceptor: Parsed error\n'
      'Original: $originalMessage\n'
      'Parsed: $cleanMessage\n'
      'Status: ${err.response?.statusCode}\n'
      'Data: ${err.response?.data}\n'
      'name: ErrorInterceptor\n',
    );

    final transformedError = CleanDioException.from(err, cleanMessage);

    handler.next(transformedError);
  }
}
