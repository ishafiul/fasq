import 'package:dio/dio.dart';
import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/core/error/default_error_parser.dart';
import 'package:ecommerce/core/error/error_interceptor.dart';
import 'package:ecommerce/core/error/error_parser.dart';
import 'package:ecommerce/core/get_it.config.dart';
import 'package:ecommerce/core/interceptors/auth_interceptor.dart';
import 'package:ecommerce/core/interceptors/token_refresh_interceptor.dart';
import 'package:ecommerce/core/services/auth_service.dart';
import 'package:ecommerce/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

/// The main locator for the application.
///
/// This locator is used to access all the dependencies of the application.
final locator = GetIt.instance;

/// Initializes the dependencies of the application.
///
/// This method initializes the app environment and the dependencies of the application.
@injectableInit
Future<void> initializeDependencies() async {
  await Future.value(locator.init());
}

/// Module for the external dependencies of the application.
///
/// This module provides the dependencies for the application.
@module
abstract class ExternalDependencies {
  /// The error parser instance for the application.
  ///
  /// This parser is used to extract clean error messages from API responses.
  /// Override this to use a custom error parser for different backend formats.
  @singleton
  ErrorParser get errorParser => const DefaultErrorParser();

  /// The Dio instance for the application.
  ///
  /// This Dio instance is used to make the API calls to the server.
  @singleton
  Dio dio(ErrorParser errorParser) {
    final instance = Dio(
      BaseOptions(
        baseUrl: "https://fasq-test-api.shafi.dev/api",
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
      ),
    );

    instance.interceptors.addAll([
      AuthInterceptor(),
      TokenRefreshInterceptor(
        instance,
        onLogout: () async {
          final authService = locator.get<AuthService>();
          await authService.clearAll();
        },
      ),
      ErrorInterceptor(errorParser),
    ]);

    return instance;
  }

  /// The ApiClient instance for the application.
  ///
  /// This ApiClient instance is used to make the API calls to the server.
  @injectable
  ApiClient apiClient(Dio dio) => ApiClient(dio);

  @injectable
  ThemeData theme(@factoryParam Brightness brightness) {
    return appTheme(brightness);
  }
}
