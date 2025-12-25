import 'package:dio/dio.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/services/auth_service.dart';

/// Interceptor that adds the authorization token to requests.
///
/// This interceptor automatically attaches the Bearer token to
/// all API requests that require authentication.
class AuthInterceptor extends Interceptor {
  AuthInterceptor();

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final authService = locator.get<AuthService>();
    final token = await authService.getAccessToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
