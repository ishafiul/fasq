/// Metrics representing query throughput over a time window.
///
/// Tracks the rate of query executions (requests per minute and per second)
/// within a specified rolling time window. Used for monitoring query load
/// and identifying high-frequency queries.
///
/// Example:
/// ```dart
/// final throughput = ThroughputMetrics(
///   requestsPerMinute: 60.0,
///   requestsPerSecond: 1.0,
///   totalRequests: 60,
///   windowStart: DateTime.now().subtract(Duration(minutes: 1)),
///   windowEnd: DateTime.now(),
/// );
/// ```
class ThroughputMetrics {
  /// Number of requests per minute within the window.
  final double requestsPerMinute;

  /// Number of requests per second within the window.
  final double requestsPerSecond;

  /// Total number of requests within the window.
  final int totalRequests;

  /// Start time of the measurement window.
  final DateTime windowStart;

  /// End time of the measurement window.
  final DateTime windowEnd;

  /// Creates a new [ThroughputMetrics] instance.
  ///
  /// [requestsPerMinute] The calculated requests per minute rate.
  /// [requestsPerSecond] The calculated requests per second rate.
  /// [totalRequests] Total number of requests in the window.
  /// [windowStart] When the measurement window began.
  /// [windowEnd] When the measurement window ended.
  const ThroughputMetrics({
    required this.requestsPerMinute,
    required this.requestsPerSecond,
    required this.totalRequests,
    required this.windowStart,
    required this.windowEnd,
  });

  /// Converts this instance to a JSON-serializable map.
  ///
  /// Returns a map containing all throughput metrics with ISO8601-formatted
  /// timestamps for the window boundaries.
  Map<String, dynamic> toJson() => {
        'requestsPerMinute': requestsPerMinute,
        'requestsPerSecond': requestsPerSecond,
        'totalRequests': totalRequests,
        'windowStart': windowStart.toIso8601String(),
        'windowEnd': windowEnd.toIso8601String(),
      };

  /// Creates a [ThroughputMetrics] instance from a JSON map.
  ///
  /// [json] A map containing serialized throughput metrics data.
  ///
  /// Returns a new [ThroughputMetrics] instance with data from [json].
  ///
  /// Throws [FormatException] if the JSON structure is invalid or required
  /// fields are missing.
  factory ThroughputMetrics.fromJson(Map<String, dynamic> json) {
    return ThroughputMetrics(
      requestsPerMinute: (json['requestsPerMinute'] as num).toDouble(),
      requestsPerSecond: (json['requestsPerSecond'] as num).toDouble(),
      totalRequests: json['totalRequests'] as int,
      windowStart: DateTime.parse(json['windowStart'] as String),
      windowEnd: DateTime.parse(json['windowEnd'] as String),
    );
  }
}
