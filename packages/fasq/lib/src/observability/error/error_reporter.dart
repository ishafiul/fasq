import 'package:fasq/src/observability/error/error_context.dart';

/// Callback for reporting query errors to external systems.
///
/// Use this callback type to integrate `fasq` error reporting with external
/// error tracking services like Sentry, Crashlytics, or custom logging systems.
///
/// The callback is invoked automatically whenever a query fails, providing
/// rich context about the failure including query key, retry count, network
/// status, and sanitized query options.
///
/// Example implementation for Sentry:
/// ```dart
/// void sentryErrorReporter(FasqErrorContext context) {
///   Sentry.captureException(
///     context.error,
///     stackTrace: context.stackTrace,
///     hint: Hint.withMap({
///       'queryKey': context.queryKey.join('/'),
///       'retryCount': context.retryCount,
///       'networkStatus': context.networkStatus ? 'online' : 'offline',
///       'sanitizedOptions': context.sanitizedQueryOptions,
///     }),
///   );
/// }
/// ```
///
/// Example usage:
/// ```dart
/// final client = QueryClient();
/// client.addErrorReporter(sentryErrorReporter);
/// ```
typedef FasqErrorReporter = void Function(FasqErrorContext context);
