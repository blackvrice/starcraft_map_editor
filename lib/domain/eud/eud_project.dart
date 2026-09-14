import 'dart:convert';

import 'eud_field_manifest.dart';

final class EudOverride {
  EudOverride({
    required this.field,
    required this.targetId,
    required this.value,
    this.overrideChk = false,
  }) {
    if (!RegExp(
          r'^[a-zA-Z][a-zA-Z0-9]*\.[a-zA-Z][a-zA-Z0-9]*$',
        ).hasMatch(field) ||
        field.length > 100 ||
        targetId < 0 ||
        targetId > 65535 ||
        !(value is bool || value is int || value is String)) {
      throw const FormatException('Invalid EUD override structure.');
    }
    if (value is String && (value as String).length > 256) {
      throw const FormatException('EUD value is too long.');
    }
  }
  final String field;
  final int targetId;
  final Object value;
  final bool overrideChk;
  String get identity => '$field:$targetId';
  Map<String, Object> toJson() => {
    'field': field,
    'targetId': targetId,
    'value': value,
    'overrideChk': overrideChk,
  };
}

/// Declarative source only. The map reference never grants permission to open,
/// execute or overwrite a file; the application must explicitly resolve it.
final class EudProject {
  EudProject({
    required this.mapPath,
    required this.mapSha256,
    Iterable<EudOverride> overrides = const [],
  }) : overrides = List.unmodifiable(overrides) {
    if (mapPath.trim().isEmpty ||
        mapPath.length > 4096 ||
        mapPath.contains('\u0000') ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(mapSha256)) {
      throw const FormatException('Invalid EUD map binding.');
    }
    if (this.overrides.length > maxOverrides) {
      throw const FormatException('Too many EUD overrides.');
    }
    final keys = <String>{};
    for (final item in this.overrides) {
      if (!keys.add(item.identity)) {
        throw FormatException('Duplicate EUD override: ${item.identity}');
      }
    }
  }
  static const schemaVersion = 1;
  static const maxOverrides = 5000;
  static const maxTextLength = 2 * 1024 * 1024;
  final String mapPath;
  final String mapSha256;
  final List<EudOverride> overrides;

  EudProject withOverrides(Iterable<EudOverride> values) =>
      EudProject(mapPath: mapPath, mapSha256: mapSha256, overrides: values);

  /// Validates editable structure, not compiler/game compatibility.
  List<String> get validationIssues {
    final issues = <String>[];
    final values = {for (final item in overrides) item.identity: item};
    for (final item in overrides) {
      final error = EudFieldManifest.validate(
        item.field,
        item.targetId,
        item.value,
      );
      if (error != null) {
        issues.add('${item.identity}:${error.name}');
        continue;
      }
      if (EudFieldManifest.find(item.field)!.overlapsChk && !item.overrideChk) {
        issues.add('${item.identity}:explicitChkOverrideRequired');
      }
      if (item.field == 'weapon.minRange') {
        final max = values['weapon.maxRange:${item.targetId}']?.value;
        if (max is int && (item.value as int) > max) {
          issues.add('${item.identity}:minimumExceedsMaximum');
        }
      }
    }
    return List.unmodifiable(issues);
  }

  String encode() {
    final ordered = [...overrides]
      ..sort((a, b) {
        final fieldOrder = a.field.compareTo(b.field);
        return fieldOrder != 0 ? fieldOrder : a.targetId.compareTo(b.targetId);
      });
    return '${const JsonEncoder.withIndent('  ').convert({
      'format': 'starcraft-map-editor-eud',
      'schemaVersion': schemaVersion,
      'map': {'path': mapPath, 'sha256': mapSha256},
      'overrides': ordered.map((item) => item.toJson()).toList(),
    })}\n';
  }

  static EudProject decode(String text) {
    if (text.length > maxTextLength) {
      throw const FormatException('EUD project exceeds size limit.');
    }
    final root = _object(jsonDecode(text), {
      'format',
      'schemaVersion',
      'map',
      'overrides',
    });
    if (root['format'] != 'starcraft-map-editor-eud' ||
        root['schemaVersion'] is! int ||
        root['schemaVersion'] != schemaVersion) {
      throw const FormatException(
        'Unsupported EUD project schema; migration required.',
      );
    }
    final map = _object(root['map'], {'path', 'sha256'});
    final entries = root['overrides'];
    if (map['path'] is! String ||
        map['sha256'] is! String ||
        entries is! List ||
        entries.length > maxOverrides) {
      throw const FormatException('Invalid EUD project structure.');
    }
    final overrides = <EudOverride>[];
    for (final entry in entries) {
      final item = _object(entry, {
        'field',
        'targetId',
        'value',
        'overrideChk',
      });
      if (item['field'] is! String ||
          item['targetId'] is! int ||
          item['value'] == null ||
          item['overrideChk'] is! bool) {
        throw const FormatException('Invalid EUD override structure.');
      }
      overrides.add(
        EudOverride(
          field: item['field'] as String,
          targetId: item['targetId'] as int,
          value: item['value'] as Object,
          overrideChk: item['overrideChk'] as bool,
        ),
      );
    }
    return EudProject(
      mapPath: map['path'] as String,
      mapSha256: map['sha256'] as String,
      overrides: overrides,
    );
  }

  static Map<String, dynamic> _object(Object? value, Set<String> keys) {
    if (value is! Map<String, dynamic> ||
        value.length != keys.length ||
        !keys.containsAll(value.keys)) {
      throw const FormatException('Unknown or missing EUD project properties.');
    }
    return value;
  }
}
