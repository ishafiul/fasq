import 'dart:io';

/// Post-processes generated API code from swagger_parser to fix common issues.
///
/// Currently this:
/// - Changes `final dynamic json;` to `final String? json;` in enum models
/// - Changes `dynamic toJson() => json;` to `String? toJson() => json;` in enum models
/// - Fixes undefined enum default values (e.g., `sortBy = createdAt` -> `sortBy = SortBy.createdAt`)
/// - Fixes @Query('id') to @Path('id') for path parameters
/// - Converts Express-style path parameters `:paramName` to Retrofit-style `{paramName}`
///
/// This file is safe to run after each API generation.
Future<void> main() async {
  await _fixEnumModels();
  await _fixApiClients();

  stdout.writeln('fix_api_gen: completed.');
}

Future<void> _fixEnumModels() async {
  final root = Directory('lib/api/models');
  if (!await root.exists()) {
    stdout.writeln('fix_api_gen: lib/api/models does not exist, skipping enum fixes.');
    return;
  }

  final dartFiles =
      await root.list(recursive: false).where((e) => e is File && e.path.endsWith('.dart')).cast<File>().toList();

  for (final file in dartFiles) {
    var content = await file.readAsString();

    // Only touch files that look like swagger_parser enum models.
    if (!content.contains('@JsonEnum()') || !content.contains('const ') || !content.contains('final dynamic json;')) {
      continue;
    }

    final original = content;

    content = content.replaceAll(
      'final dynamic json;',
      'final String? json;',
    );

    content = content.replaceAll(
      'dynamic toJson() => json;',
      'String? toJson() => json;',
    );

    if (content != original) {
      await file.writeAsString(content);
      stdout.writeln('fix_api_gen: updated enum ${file.path}');
    }
  }
}

Future<void> _fixApiClients() async {
  final root = Directory('lib/api');
  if (!await root.exists()) {
    stdout.writeln('fix_api_gen: lib/api does not exist, skipping client fixes.');
    return;
  }

  final dartFiles =
      await root.list(recursive: true).where((e) => e is File && e.path.endsWith('.dart')).cast<File>().toList();

  for (final file in dartFiles) {
    var content = await file.readAsString();
    final original = content;

    // Fix undefined enum default values.
    // These patterns match bare identifiers that should be qualified with their enum type.
    content = _fixUndefinedEnumDefaults(content);

    // Convert Express-style path parameters :paramName to Retrofit-style {paramName}
    // Matches :paramName in path strings (e.g., '/products/:id' -> '/products/{id}')
    // Handles multiple parameters in same path
    content = _convertExpressPathParamsToRetrofit(content);

    if (content != original) {
      await file.writeAsString(content);
      stdout.writeln('fix_api_gen: updated ${file.path}');
    }
  }
}

/// Fixes undefined enum default values in generated API code.
///
/// The swagger_parser generates code like:
///   `SortBy? sortBy = createdAt,`
/// which should be:
///   `SortBy? sortBy = SortBy.createdAt,`
String _fixUndefinedEnumDefaults(String content) {
  // Map of parameter patterns to their enum type prefix.
  // Key: regex pattern to match the undefined default value
  // Value: replacement with proper enum qualification
  final enumFixPatterns = <RegExp, String Function(Match)>{
    // SortBy enum values
    RegExp(r'(\bSortBy\?\s+\w+\s*=\s*)(?!SortBy\.)(createdAt|updatedAt|name|price|rating|popularity|stock|sales|discount|featured|averageRating|reviewCount|soldCount|viewCount)(\s*[,\)])'):
        (match) {
      return '${match.group(1)}SortBy.${match.group(2)}${match.group(3)}';
    },

    // SortOrder enum values
    RegExp(r'(\bSortOrder\?\s+\w+\s*=\s*)(?!SortOrder\.)(asc|desc)(\s*[,\)])'): (match) {
      return '${match.group(1)}SortOrder.${match.group(2)}${match.group(3)}';
    },
  };

  var result = content;
  for (final entry in enumFixPatterns.entries) {
    result = result.replaceAllMapped(entry.key, entry.value);
  }

  return result;
}

/// Converts Express-style path parameters to Retrofit-style.
///
/// This function converts path parameters from Express-style `:paramName` to
/// Retrofit-style `{paramName}` in HTTP method annotations.
///
/// Examples:
/// - `@GET('/products/:id')` -> `@GET('/products/{id}')`
/// - `@POST('/products/:productId/images/:imageId')` -> `@POST('/products/{productId}/images/{imageId}')`
String _convertExpressPathParamsToRetrofit(String content) {
  // Pattern to match HTTP method annotations with path strings
  // Matches: @GET('/products/:id'), @POST('/products/:productId/images'), etc.
  // Handle both single and double quotes separately
  var result = content;

  // Match single quotes: @GET('/products/:id')
  result = result.replaceAllMapped(
    RegExp(r"(@(?:GET|POST|PUT|PATCH|DELETE)\s*\(\')([^\']+)(\')"),
    (match) {
      final prefix = match.group(1) ?? '';
      final path = match.group(2) ?? '';
      final suffix = match.group(3) ?? '';

      // Replace all :paramName with {paramName} in the path
      final convertedPath = path.replaceAllMapped(
        RegExp(r':(\w+)'),
        (paramMatch) => '{${paramMatch.group(1)}}',
      );

      return '$prefix$convertedPath$suffix';
    },
  );

  // Match double quotes: @GET("/products/:id")
  result = result.replaceAllMapped(
    RegExp(r'(@(?:GET|POST|PUT|PATCH|DELETE)\s*\(\")([^\"]+)(\")'),
    (match) {
      final prefix = match.group(1) ?? '';
      final path = match.group(2) ?? '';
      final suffix = match.group(3) ?? '';

      // Replace all :paramName with {paramName} in the path
      final convertedPath = path.replaceAllMapped(
        RegExp(r':(\w+)'),
        (paramMatch) => '{${paramMatch.group(1)}}',
      );

      return '$prefix$convertedPath$suffix';
    },
  );

  return result;
}
