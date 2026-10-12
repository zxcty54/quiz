import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the v2 architecture rules so a future edit cannot silently undo the
/// refactor (this is the test that would have failed in v1 many times over).
void main() {
  final Directory lib = Directory('lib');

  List<File> dartFiles() => lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  List<String> importLines(File file) => file
      .readAsLinesSync()
      .where((String l) => l.trimLeft().startsWith('import '))
      .toList();

  test('every import is absolute (package:mocktester_v2 or a dependency)', () {
    final List<String> offenders = <String>[];
    for (final File file in dartFiles()) {
      for (final String line in importLines(file)) {
        final RegExpMatch? match =
            RegExp(r"import\s+'([^']+)'").firstMatch(line);
        if (match == null) continue;
        final String target = match.group(1)!;
        if (!target.startsWith('dart:') && !target.startsWith('package:')) {
          offenders.add('${file.path} → $target');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'relative imports are not allowed:\n${offenders.join('\n')}');
  });

  test('no v1 import paths survive (package:mocktester/)', () {
    final List<String> offenders = <String>[];
    for (final File file in dartFiles()) {
      for (final String line in importLines(file)) {
        if (line.contains("package:mocktester/")) {
          offenders.add('${file.path} → $line');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('remote URLs live only in core/config', () {
    final RegExp urlPattern = RegExp(r'https?://(raw|cdn|fastly|api)\.');
    final List<String> offenders = <String>[];
    for (final File file in dartFiles()) {
      final String path = file.path.replaceAll(r'\', '/');
      if (path.contains('core/config/')) continue; // the registry itself
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        // allow doc-comment examples and the launcher icon name
        if (line.trimLeft().startsWith('///') || line.trimLeft().startsWith('//')) {
          continue;
        }
        if (urlPattern.hasMatch(line)) {
          offenders.add('$path:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'hardcoded CDN/repo URLs found:\n${offenders.join('\n')}');
  });

  test('secrets are only read through AppSecrets', () {
    final RegExp tokenPattern =
        RegExp(r'[0-9]{8,12}:AA[A-Za-z0-9_\-]{20,}');
    final List<String> offenders = <String>[];
    for (final File file in dartFiles()) {
      if (file.path.replaceAll(r'\', '/').endsWith('core/config/app_secrets.dart')) {
        continue;
      }
      if (tokenPattern.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'hardcoded bot tokens found in:\n${offenders.join('\n')}');
  });

  test('features never import other features presentation layers blindly', () {
    // core must stay dependency-free: no feature imports inside core/*.
    final List<String> offenders = <String>[];
    for (final File file in dartFiles()) {
      final String path = file.path.replaceAll(r'\', '/');
      if (!path.contains('/core/')) continue;
      for (final String line in importLines(file)) {
        if (line.contains('package:mocktester_v2/features/')) {
          // The remote-config service is allowed to reach the AI routing table,
          // everything else is a layering violation.
          if (!path.endsWith('core/config/remote_config_service.dart')) {
            offenders.add('$path → $line');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
