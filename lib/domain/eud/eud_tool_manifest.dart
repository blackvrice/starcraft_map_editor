import 'dart:convert';

/// Expected inventory supplied by the app, never trusted from a tool folder.
final class EudToolManifest {
  EudToolManifest({
    required this.version,
    required this.artifactSha256,
    required this.sourceUrl,
    required Map<String, EudToolFile> files,
  }) : files = Map.unmodifiable(files) {
    if (!RegExp(r'^\d{1,5}\.\d{1,5}\.\d{1,5}\.\d{1,5}$').hasMatch(version) ||
        version.split('.').any((v) => int.parse(v) > 65535) ||
        !validHash(artifactSha256)) {
      throw const FormatException('Invalid tool version or artifact hash.');
    }
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        sourceUrl.length > 2048) {
      throw const FormatException('Expected an HTTPS artifact source.');
    }
    if (files.isEmpty || files.length > 4096) {
      throw const FormatException('Invalid inventory size.');
    }
    final names = <String>{};
    var total = 0;
    for (final entry in files.entries) {
      validatePath(entry.key);
      if (!names.add(entry.key.toLowerCase())) {
        throw const FormatException('Duplicate Windows file path.');
      }
      total += entry.value.size;
    }
    if (total > 4 * 1024 * 1024 * 1024) {
      throw const FormatException('Package exceeds size limit.');
    }
    if (!files.containsKey('euddraft.exe') ||
        !files.containsKey('VERSION') ||
        !files.containsKey('license.txt')) {
      throw const FormatException(
        'Required package inventory entries missing.',
      );
    }
    for (final path in names) {
      final parts = path.split('/');
      for (var i = 1; i < parts.length; i++) {
        if (names.contains(parts.take(i).join('/'))) {
          throw const FormatException('File/directory path collision.');
        }
      }
    }
  }
  final String version;
  final String artifactSha256;
  final String sourceUrl;
  final Map<String, EudToolFile> files;
  static bool validHash(String value) =>
      RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
  static void validatePath(String path) {
    if (path.length > 240 || path.isEmpty) {
      throw const FormatException('Invalid package path.');
    }
    for (final part in path.split('/')) {
      if (!RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$').hasMatch(part) ||
          part.endsWith('.') ||
          RegExp(
            r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)',
            caseSensitive: false,
          ).hasMatch(part)) {
        throw const FormatException('Unsafe package path.');
      }
    }
  }

  factory EudToolManifest.decode(String text) {
    if (text.length > 2 * 1024 * 1024) {
      throw const FormatException('Manifest exceeds size limit.');
    }
    final root = jsonDecode(text);
    if (root is! Map<String, dynamic> ||
        root.length != 6 ||
        root['format'] != 'starcraft-map-editor-eud-tool' ||
        root['schemaVersion'] is! int ||
        root['schemaVersion'] != 1 ||
        root['version'] is! String ||
        root['artifactSha256'] is! String ||
        root['sourceUrl'] is! String ||
        root['files'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported tool manifest.');
    }
    final files = <String, EudToolFile>{};
    for (final entry in (root['files'] as Map<String, dynamic>).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic> ||
          value.length != 2 ||
          value['size'] is! int ||
          value['sha256'] is! String) {
        throw const FormatException('Invalid inventory entry.');
      }
      files[entry.key] = EudToolFile(
        size: value['size'] as int,
        sha256: value['sha256'] as String,
      );
    }
    return EudToolManifest(
      version: root['version'] as String,
      artifactSha256: root['artifactSha256'] as String,
      sourceUrl: root['sourceUrl'] as String,
      files: files,
    );
  }
  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert({
        'format': 'starcraft-map-editor-eud-tool',
        'schemaVersion': 1,
        'version': version,
        'artifactSha256': artifactSha256,
        'sourceUrl': sourceUrl,
        'files': {
          for (final path in (files.keys.toList()..sort())) path: {'size': files[path]!.size, 'sha256': files[path]!.sha256},
        },
      })}\n';
}

final class EudToolFile {
  EudToolFile({required this.size, required this.sha256}) {
    if (size < 0 ||
        size > 2 * 1024 * 1024 * 1024 ||
        !EudToolManifest.validHash(sha256)) {
      throw const FormatException('Invalid file size or SHA-256.');
    }
  }
  final int size;
  final String sha256;
}
