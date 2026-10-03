import 'dart:convert';

import '../../domain/assets/map_sound.dart';
import '../../domain/chk/chk.dart';
import '../../domain/eud/eud_project.dart';
import '../eud/eud_source_document.dart';
import '../ports/map_file_fingerprint_gateway.dart';
import 'opened_map_session.dart';

/// A checkpoint of committed document state, never a playable map or code entry.
final class RecoverySnapshot {
  const RecoverySnapshot({
    required this.savedAt,
    this.map,
    this.project,
    this.projectPath,
    this.source,
  });

  static const maxBytes = 192 * 1024 * 1024;
  final DateTime savedAt;
  final RecoveryMap? map;
  final EudProject? project;
  final String? projectPath;
  final EudSourceDocument? source;

  String encode() => jsonEncode({
    'schema': 1,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'map': map?.toJson(),
    'project': project?.encode(),
    'projectPath': projectPath,
    'source': source == null
        ? null
        : {
            'fileName': source!.fileName,
            'path': source!.sourcePath,
            'savedText': source!.savedText,
            'text': source!.text,
          },
  });

  factory RecoverySnapshot.decode(String content) {
    if (utf8.encode(content).length > maxBytes) {
      throw const FormatException(
        'Recovery checkpoint exceeds its size limit.',
      );
    }
    final json = jsonDecode(content) as Map<String, dynamic>;
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported recovery schema.');
    }
    final source = json['source'] as Map<String, dynamic>?;
    final path = source?['path'] as String?;
    final document = source == null
        ? null
        : path == null
        ? EudSourceDocument.untitled(
            documentId: 'recovered-source',
            fileName: source['fileName'] as String,
            initialText: source['savedText'] as String,
          )
        : EudSourceDocument.opened(
            documentId: 'recovered-source',
            sourcePath: path,
            text: source['savedText'] as String,
          );
    final snapshot = RecoverySnapshot(
      savedAt: DateTime.parse(json['savedAt'] as String).toUtc(),
      map: json['map'] == null
          ? null
          : RecoveryMap.fromJson(json['map'] as Map<String, dynamic>),
      project: json['project'] == null
          ? null
          : EudProject.decode(json['project'] as String),
      projectPath: json['projectPath'] as String?,
      source: document?.withText(source!['text'] as String),
    );
    if (snapshot.map == null &&
        snapshot.project == null &&
        snapshot.source == null) {
      throw const FormatException('Empty recovery checkpoint.');
    }
    return snapshot;
  }
}

final class RecoveryMap {
  RecoveryMap({
    required this.sourcePath,
    required this.fingerprint,
    required this.baseline,
    required this.document,
    required this.resources,
  });

  factory RecoveryMap.capture(OpenedMapSession session) => RecoveryMap(
    sourcePath: session.sourcePath,
    fingerprint: session.sourceFingerprint,
    baseline: session.extractedMap.scenarioChkBytes,
    document: session.rawDocument,
    resources: session.resourceEdits,
  );

  final String? sourcePath;
  final MapFileFingerprint? fingerprint;
  final List<int> baseline;
  final RawChkDocument document;
  final Map<String, List<int>?> resources;

  Map<String, Object?> toJson() => {
    'path': sourcePath,
    'fingerprint': fingerprint == null
        ? null
        : {
            'size': fingerprint!.sizeBytes,
            'modified': fingerprint!.modifiedAtUtc.toIso8601String(),
            'sha256': fingerprint!.sha256Digest,
          },
    'baseline': base64Encode(baseline),
    'current': base64Encode(const RawChkEncoder().encode(document)),
    'dirty': [
      for (var i = 0; i < document.sections.length; i++)
        if (document.sections[i].isDirty) i,
    ],
    'resources': resources.map(
      (path, bytes) =>
          MapEntry(path, bytes == null ? null : base64Encode(bytes)),
    ),
  };

  factory RecoveryMap.fromJson(Map<String, dynamic> json) {
    final path = json['path'] as String?;
    final fp = json['fingerprint'] as Map<String, dynamic>?;
    if ((path == null) != (fp == null) ||
        (path != null && !RegExp(r'^(?:[a-zA-Z]:[\\/]|\\\\)').hasMatch(path))) {
      throw const FormatException('Invalid recovery map source.');
    }
    final baseline = base64Decode(json['baseline'] as String);
    final original = const RawChkParser().parse(baseline);
    final parsed = const RawChkParser().parse(
      base64Decode(json['current'] as String),
    );
    if (!original.isSuccess ||
        !parsed.isSuccess ||
        parsed.document!.sections.any((s) => s.isEuddraftProtectionMarker)) {
      throw const FormatException('Invalid recovery CHK.');
    }
    var document = parsed.document!;
    final dirty = (json['dirty'] as List<dynamic>).cast<int>();
    for (final index in dirty) {
      final section = document.sections[index];
      document = document.replaceSection(
        index,
        section.withPayload(section.payload),
      );
    }
    final resources = <String, List<int>?>{};
    final encoded = json['resources'] as Map<String, dynamic>;
    if (encoded.length > 512) {
      throw const FormatException('Too many resources.');
    }
    for (final entry in encoded.entries) {
      if (MapSound.path(entry.key) != entry.key) {
        throw const FormatException('Invalid recovery resource path.');
      }
      final bytes = entry.value == null
          ? null
          : base64Decode(entry.value as String);
      if (bytes != null) MapSound.validate(bytes);
      resources[entry.key] = bytes;
    }
    return RecoveryMap(
      sourcePath: path,
      fingerprint: fp == null
          ? null
          : MapFileFingerprint(
              sizeBytes: fp['size'] as int,
              modifiedAt: DateTime.parse(fp['modified'] as String),
              sha256Digest: fp['sha256'] as String,
            ),
      baseline: baseline,
      document: document,
      resources: resources,
    );
  }
}
