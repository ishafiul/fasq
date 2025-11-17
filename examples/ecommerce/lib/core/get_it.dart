import 'package:dio/dio.dart';
import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/core/get_it.config.dart';
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
  /// The Dio instance for the application.
  ///
  /// This Dio instance is used to make the API calls to the server.
  @singleton
  Dio get dio {
    final instance = Dio(
      BaseOptions(
        baseUrl: "https://example_backend.shafiulislam20.workers.dev",
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    return instance;
  }

  /// The ApiClient instance for the application.
  ///
  /// This ApiClient instance is used to make the API calls to the server.
  @injectable
  ApiClient apiClient([@factoryParam Dio? dio]) => ApiClient(dio ?? this.dio);

  @injectable
  ThemeData theme(@factoryParam Brightness brightness) {
    return appTheme(brightness);
  }
}
