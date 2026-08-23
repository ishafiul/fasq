import 'dart:io';

/// Synchronizes package versions from pubspec.yaml into README files.
///
/// Run normally to update files:
///   dart run tool/sync_readme_versions.dart
///
/// Run with --check in CI to fail when a README is stale:
///   dart run tool/sync_readme_versions.dart --check
void main(List<String> arguments) {
  final checkOnly = arguments.contains('--check');
  final versions = <String, String>{};
  final readmes = <File>[File('README.md')];

  final packagesDirectory = Directory('packages');
  if (packagesDirectory.existsSync()) {
    for (final entity in packagesDirectory.listSync()) {
      if (entity is! Directory) continue;

      final pubspec = File('${entity.path}/pubspec.yaml');
      final readme = File('${entity.path}/README.md');
      if (!pubspec.existsSync() || !readme.existsSync()) continue;

      final pubspecText = pubspec.readAsStringSync();
      final name = _match(pubspecText, r'^name:\s*([^\s#]+)$');
      final version = _match(pubspecText, r'^version:\s*([^\s#]+)$');
      if (name == null || version == null) continue;

      versions[name] = version;
      readmes.add(readme);
    }
  }

  final stale = <String>[];
  for (final readme in readmes) {
    final original = readme.readAsStringSync();
    final updated = _synchronize(original, versions);
    if (updated == original) continue;

    if (checkOnly) {
      stale.add(readme.path);
    } else {
      readme.writeAsStringSync(updated);
      stdout.writeln('Updated ${readme.path}');
    }
  }

  if (stale.isNotEmpty) {
    stderr.writeln('README versions are out of sync:');
    for (final path in stale) {
      stderr.writeln('  $path');
    }
    exitCode = 1;
  }
}

String? _match(String text, String pattern) {
  return RegExp(pattern, multiLine: true).firstMatch(text)?.group(1);
}

String _synchronize(String text, Map<String, String> versions) {
  var updated = text.replaceFirstMapped(
    RegExp(r'^(\*\*Current Version:\*\*\s*)[^\s]+', multiLine: true),
    (match) => '${match.group(1)}${_versionForCurrentReadme(text, versions)}',
  );

  for (final entry in versions.entries) {
    final name = RegExp.escape(entry.key);
    final version = entry.value;

    updated = updated.replaceAllMapped(
      RegExp('(^|\\s)$name:\\s*\\^?[^\\s`|]+', multiLine: true),
      (match) => '${match.group(1)}${entry.key}: ^$version',
    );
    updated = updated.replaceAllMapped(
      RegExp('(`$name`\\s*\\|[^|]*\\|\\s*)\\^?[^\\s|`]+'),
      (match) => '${match.group(1)}^$version',
    );
  }

  return updated;
}

String _versionForCurrentReadme(String text, Map<String, String> versions) {
  for (final entry in versions.entries) {
    if (text.contains('pub/v/${entry.key}?')) {
      return entry.value;
    }
  }
  return versions.values.first;
}
