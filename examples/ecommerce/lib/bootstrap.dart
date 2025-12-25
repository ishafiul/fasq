import 'dart:async';

import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/services/query_client_service.dart';
import 'package:ecommerce/core/services/snackbar_manager.dart';
import 'package:ecommerce/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stack_trace/stack_trace.dart';

/// This function is responsible for bootstrap all utilities that needs to initialize
/// before app main UI start.
///
/// It handles:
/// - Error handling setup (FlutterError.onError and runZonedGuarded)
/// - System preferences (orientation, etc.)
/// - Dependency injection initialization
/// - License registry setup (if needed)
///
/// Usage:
/// ```dart
/// void main() {
///   bootstrap(() => const MyApp());
/// }
/// ```
Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      await initializeDependencies();

      final queryClientService = locator<QueryClientService>();
      await queryClientService.initialize();

      final snackbarManager = locator<SnackbarManager>();
      queryClientService.client.addObserver(snackbarManager);

      FlutterError.onError = (FlutterErrorDetails details) {
        final stack = details.stack;
        if (stack == null) return;
        logger.e(details.exceptionAsString(), stackTrace: details.stack == null ? null : Trace.from(stack));
      };

      runApp(await builder());
    },
    (Object error, StackTrace stackTrace) {
      logger.e(error.toString(), stackTrace: Trace.from(stackTrace));

      // Handle specific error types
      if (error is FlutterError) {
        final message = error.message.toLowerCase();
        if (message.contains('renderflex')) {
          logger.e('RenderFlex overflow: $error, ${Trace.from(stackTrace)}');
        } else if (message.contains('cannot emit new states')) {
          logger.e('State emission error: $error, ${Trace.from(stackTrace)}');
        } else {
          logger.e('Flutter error: $error, ${Trace.from(stackTrace)}');
        }
      } else {
        logger.t('Unhandled error: $error, ${Trace.from(stackTrace)}');
      }
    },
  );
}
