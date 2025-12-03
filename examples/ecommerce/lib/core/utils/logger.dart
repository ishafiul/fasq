import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Global logger instance for the application.
///
/// Configured differently for debug and release modes.
final logger = Logger(
  printer: PrettyPrinter(
    lineLength: 100,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: kDebugMode ? Level.debug : Level.warning,
);
