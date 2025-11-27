import 'dart:io';

/// Post-processes generated enum models from swagger_parser to improve typing.
///
/// Currently this:
/// - Changes `final dynamic json;` to `final String? json;`
/// - Changes `dynamic toJson() => json;` to `String? toJson() => json;`
/// - Leaves `$unknown(null)` and fromJson logic intact so unknown_enum_value semantics remain.
///
/// This file is safe to run after each API generation and can be extended later
/// if you want to further tweak generated enums.
Future<void> main() async {
  await _fixEnumModels();

  stdout.writeln('fix_enums: completed.');
}

Future<void> _fixEnumModels() async {
  final root = Directory('lib/api/models');
  if (!await root.exists()) {
    stdout.writeln('fix_enums: lib/api/models does not exist, skipping enum fixes.');
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
      stdout.writeln('fix_enums: updated ${file.path}');
    }
    await _fixApiClients();
  }
}

Future<void> _fixApiClients() async {
  final root = Directory('lib/api');
  if (!await root.exists()) {
    stdout.writeln('fix_enums: lib/api does not exist, skipping client fixes.');
    return;
  }

  final dartFiles =
      await root.list(recursive: true).where((e) => e is File && e.path.endsWith('.dart')).cast<File>().toList();

  for (final file in dartFiles) {
    var content = await file.readAsString();
    final original = content;

    // Fix default enum values for sortBy / sortOrder wherever they appear.
    // Handle both with and without @Query annotation (for .g.dart files)
    content = content.replaceAll(
      "@Query('sortBy') SortBy? sortBy = createdAt,",
      "@Query('sortBy') SortBy? sortBy = SortBy.createdAt,",
    );
    // Fix in .g.dart files (without @Query annotation)
    // Match: "SortBy? sortBy = createdAt," (with any leading whitespace)
    content = content.replaceAll(
      'sortBy = createdAt,',
      'sortBy = SortBy.createdAt,',
    );
    content = content.replaceAll(
      "@Query('sortOrder') SortOrder? sortOrder = desc,",
      "@Query('sortOrder') SortOrder? sortOrder = SortOrder.desc,",
    );
    // Fix in .g.dart files (without @Query annotation)
    // Match: "SortOrder? sortOrder = desc," (with any leading whitespace)
    content = content.replaceAll(
      'sortOrder = desc,',
      'sortOrder = SortOrder.desc,',
    );

    // Fix path/query mismatch for common :id style endpoints:
    // change @Query('id') to @Path('id') in API clients.
    content = content.replaceAll(
      "@Query('id') required String id,",
      "@Path('id') required String id,",
    );

    if (content != original) {
      await file.writeAsString(content);
      stdout.writeln('fix_enums: updated ${file.path}');
    }
  }
}
