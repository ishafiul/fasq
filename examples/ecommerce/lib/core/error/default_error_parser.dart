import 'package:dio/dio.dart';
import 'package:ecommerce/core/error/error_parser.dart';

/// Default implementation of [ErrorParser] for common API error formats.
///
/// This parser handles multiple common error response structures:
/// - Root level message: `{"message": "error"}`
/// - Nested error object: `{"error": {"message": "error"}}`
/// - Array of errors: `{"errors": ["error1", "error2"]}`
/// - Error array of objects: `{"errors": [{"message": "error1"}]}`
///
/// Falls back to DioException message if no parseable error is found.
class DefaultErrorParser extends ErrorParser {
  /// Creates a default error parser.
  const DefaultErrorParser();

  @override
  String parse(DioException exception) {
    final response = exception.response;
    final data = response?.data;

    if (data == null) {
      return _getFallbackMessage(exception);
    }

    if (data is Map<String, dynamic>) {
      final message = _parseMapError(data);
      if (message != null) {
        return message;
      }
    }

    if (data is String) {
      return data;
    }

    return _getFallbackMessage(exception);
  }

  String? _parseMapError(Map<String, dynamic> data) {
    if (data['message'] != null) {
      return data['message'].toString();
    }

    if (data['error'] != null) {
      final error = data['error'];
      if (error is String) {
        return error;
      }
      if (error is Map<String, dynamic> && error['message'] != null) {
        return error['message'].toString();
      }
    }

    if (data['errors'] != null) {
      return _parseErrorsArray(data['errors']);
    }

    return null;
  }

  String? _parseErrorsArray(dynamic errors) {
    if (errors is! List || errors.isEmpty) {
      return null;
    }

    final firstError = errors.first;

    if (firstError is String) {
      return firstError;
    }

    if (firstError is Map<String, dynamic> && firstError['message'] != null) {
      return firstError['message'].toString();
    }

    return null;
  }

  String _getFallbackMessage(DioException exception) {
    final statusCode = exception.response?.statusCode;

    if (statusCode != null) {
      return _getStatusCodeMessage(statusCode);
    }

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return exception.message ?? 'An unexpected error occurred.';
    }
  }

  String _getStatusCodeMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request. Please check your input.';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Access forbidden.';
      case 404:
        return 'Resource not found.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'Request failed with status code $statusCode.';
    }
  }
}
