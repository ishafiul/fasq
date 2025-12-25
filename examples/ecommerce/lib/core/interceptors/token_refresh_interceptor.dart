import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/services/auth_service.dart';

/// Interceptor that handles automatic token refresh on 401 errors.
///
/// When a request receives a 401 (Unauthorized) response:
/// 1. Attempts to refresh the token using the refresh token endpoint
/// 2. Updates the stored token
/// 3. Retries the original request with the new token
/// 4. If refresh fails, logs out the user
///
/// Uses a lock to prevent concurrent refresh attempts.
class TokenRefreshInterceptor extends Interceptor {
  final Dio _dio;
  final void Function()? _onLogout;

  bool _isRefreshing = false;
  final List<_RetryRequest> _requestQueue = [];

  TokenRefreshInterceptor(this._dio, {void Function()? onLogout}) : _onLogout = onLogout;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final requestOptions = err.requestOptions;

    if (requestOptions.path.contains('/auth/refresh-token')) {
      _handleRefreshFailure();
      return handler.reject(err);
    }

    if (_isRefreshing) {
      final completer = Completer<Response>();
      _requestQueue.add(_RetryRequest(requestOptions, completer));

      try {
        final response = await completer.future;
        return handler.resolve(response);
      } catch (e) {
        return handler.reject(e is DioException ? e : DioException(requestOptions: requestOptions, error: e));
      }
    }

    _isRefreshing = true;

    try {
      final authService = locator.get<AuthService>();
      final newToken = await authService.refreshToken();

      requestOptions.headers['Authorization'] = 'Bearer $newToken';

      for (final queuedRequest in _requestQueue) {
        queuedRequest.options.headers['Authorization'] = 'Bearer $newToken';
      }

      final response = await _retry(requestOptions);

      for (final queuedRequest in _requestQueue) {
        await _retryQueuedRequest(queuedRequest);
      }

      _requestQueue.clear();

      return handler.resolve(response);
    } catch (e) {
      _handleRefreshFailure();

      for (final queuedRequest in _requestQueue) {
        queuedRequest.completer.completeError(
          DioException(requestOptions: queuedRequest.options, error: 'Token refresh failed'),
        );
      }

      _requestQueue.clear();

      return handler.reject(
        DioException(requestOptions: requestOptions, error: 'Token refresh failed', response: err.response),
      );
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response> _retry(RequestOptions requestOptions) {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
      contentType: requestOptions.contentType,
      responseType: requestOptions.responseType,
      validateStatus: requestOptions.validateStatus,
      receiveTimeout: requestOptions.receiveTimeout,
      sendTimeout: requestOptions.sendTimeout,
      extra: requestOptions.extra,
    );

    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Future<void> _retryQueuedRequest(_RetryRequest queuedRequest) async {
    try {
      final response = await _retry(queuedRequest.options);
      queuedRequest.completer.complete(response);
    } catch (e) {
      queuedRequest.completer.completeError(e);
    }
  }

  void _handleRefreshFailure() {
    _onLogout?.call();
  }
}

class _RetryRequest {
  final RequestOptions options;
  final Completer<Response> completer;

  _RetryRequest(this.options, this.completer);
}
