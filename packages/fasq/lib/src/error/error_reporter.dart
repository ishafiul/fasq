import 'error_context.dart';

/// Interface for reporting query errors to external systems.
///
/// Implement this interface to integrate `fasq` error reporting with external
/// error tracking services like Sentry, Crashlytics, or custom logging systems.
///
/// The [report] method will be called automatically whenever a query fails,
/// providing rich context about the failure including query key, retry count,
/// network status, and sanitized query options.
///
/// Example implementation for Sentry:
/// ```dart
/// class SentryErrorReporter implements FasqErrorReporter {
///   @override
///   void report(FasqErrorContext context) {
///     Sentry.captureException(
///       context.error,
///       stackTrace: context.stackTrace,
///       hint: Hint.withMap({
///         'queryKey': context.queryKey.join('/'),
///         'retryCount': context.retryCount,
///         'networkStatus': context.networkStatus ? 'online' : 'offline',
///         'sanitizedOptions': context.sanitizedQueryOptions,
///       }),
///     );
///   }
/// }
/// ```
///
/// Example usage:
/// ```dart
/// final client = QueryClient();
/// client.addErrorReporter(SentryErrorReporter());
/// ```
abstract class FasqErrorReporter {
  /// Reports a query error with its context to an external system.
  ///
  /// This method is called automatically by `fasq` whenever a query fails.
  /// The [context] parameter contains all relevant information about the
  /// failure, including the error, stack trace, query key, retry count,
  /// network status, and sanitized query options.
  ///
  /// Implementations should handle errors gracefully - if reporting fails,
  /// it should not crash the application. The error reporting pipeline
  /// will catch and log any exceptions thrown by this method.
  ///
  /// [context] - Complete error context including error, stack trace, and
  ///             sanitized query metadata.
  void report(FasqErrorContext context);
}

