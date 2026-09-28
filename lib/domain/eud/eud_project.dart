import 'dart:convert';

import 'eud_field_manifest.dart';
import 'eud_execution_rule.dart';
import 'eud_rule_expression.dart';

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
    Iterable<EudExecutionRule> rules = const [],
  }) : overrides = List.unmodifiable(overrides),
       rules = List.unmodifiable(rules) {
    if (mapPath.trim().isEmpty ||
        mapPath.length > 4096 ||
        mapPath.contains('\u0000') ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(mapSha256)) {
      throw const FormatException('Invalid EUD map binding.');
    }
    if (this.overrides.length > maxOverrides) {
      throw const FormatException('Too many EUD overrides.');
    }
    if (this.rules.length > maxRules ||
        this.rules.map((r) => r.id).toSet().length != this.rules.length) {
      throw const FormatException('Too many or duplicate EUD execution rules.');
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
  static const maxRules = 64;
  static const maxTextLength = 2 * 1024 * 1024;
  final String mapPath;
  final String mapSha256;
  final List<EudOverride> overrides;
  final List<EudExecutionRule> rules;
  bool get hasGeneratedContent => overrides.isNotEmpty || rules.isNotEmpty;

  EudProject withRules(Iterable<EudExecutionRule> values) => EudProject(
    mapPath: mapPath,
    mapSha256: mapSha256,
    overrides: overrides,
    rules: values,
  );

  EudProject withOverrides(Iterable<EudOverride> values) => EudProject(
    mapPath: mapPath,
    mapSha256: mapSha256,
    overrides: values,
    rules: rules,
  );

  /// Validates editable structure, not compiler/game compatibility.
  List<String> get validationIssues {
    final issues = <String>[];
    final writes = <String>{};
    for (final rule in rules.where((r) => r.enabled)) {
      if (!writes.add(rule.writeTarget)) {
        issues.add('${rule.id}:duplicateResourceWrite:${rule.writeTarget}');
      }
    }
    final graph = <int, Set<int>>{};
    var unitRules = 0;
    for (final rule in rules.where((r) => r.enabled)) {
      final e = rule.extension;
      if (e == null) continue;
      if (e.usesUnit) unitRules++;
      if (e.action == EudRuleAction.variable) {
        graph[e.target] = e.values
            .where((v) => v.source == EudValueSource.variable)
            .map((v) => v.index)
            .toSet();
      }
    }
    if (unitRules > 4) issues.add('unitScanBudgetExceeded:4');
    if (_hasCycle(graph)) issues.add('cyclicVariableRules');
    final dependencies = <String, Set<String>>{};
    for (final rule in rules.where(
      (r) => r.enabled && r.extension != null && !r.extension!.localDisplay,
    )) {
      final reads = <String>{};
      for (final v in rule.extension!.values) {
        final key = switch (v.source) {
          EudValueSource.constant => null,
          EudValueSource.variable => 'variable:${v.index}',
          EudValueSource.minerals => '${v.player}:ore',
          EudValueSource.gas => '${v.player}:gas',
          EudValueSource.upgrade => 'upgrade:${v.player}:${v.index}',
          EudValueSource.technology => 'technology:${v.player}:${v.index}',
        };
        if (key != null && key != rule.writeTarget) reads.add(key);
      }
      dependencies[rule.writeTarget] = reads;
    }
    if (_hasCycle(dependencies)) issues.add('cyclicRuleDependencies');
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
      const orderedPairs = {
        'weapon.splashInnerRadius': [
          'weapon.splashMiddleRadius',
          'weapon.splashOuterRadius',
        ],
        'weapon.splashMiddleRadius': ['weapon.splashOuterRadius'],
        'unit.whatSoundStart': ['unit.whatSoundEnd'],
        'unit.pissedSoundStart': ['unit.pissedSoundEnd'],
        'unit.yesSoundStart': ['unit.yesSoundEnd'],
      };
      for (final upperField in orderedPairs[item.field] ?? const <String>[]) {
        final upper = values['$upperField:${item.targetId}']?.value;
        if (upper is int && item.value is int && (item.value as int) > upper) {
          issues.add('${item.identity}:exceeds:$upperField');
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
      'schemaVersion': rules.any((r) => r.extension != null)
          ? 3
          : rules.isEmpty
          ? schemaVersion
          : 2,
      if (rules.isNotEmpty) 'rules': rules.map((r) => r.toJson()).toList(),
      'map': {'path': mapPath, 'sha256': mapSha256},
      'overrides': ordered.map((item) => item.toJson()).toList(),
    })}\n';
  }

  static EudProject decode(String text) {
    if (text.length > maxTextLength) {
      throw const FormatException('EUD project exceeds size limit.');
    }
    final decoded = jsonDecode(text);
    final version = decoded is Map<String, dynamic>
        ? decoded['schemaVersion']
        : null;
    final root = _object(decoded, {
      'format',
      'schemaVersion',
      'map',
      'overrides',
      if (version == 2 || version == 3) 'rules',
    });
    if (root['format'] != 'starcraft-map-editor-eud' ||
        root['schemaVersion'] is! int ||
        (root['schemaVersion'] != schemaVersion &&
            root['schemaVersion'] != 2 &&
            root['schemaVersion'] != 3)) {
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
    final rawRules = (version == 2 || version == 3)
        ? root['rules']
        : <Object>[];
    if (rawRules is! List || rawRules.length > maxRules) {
      throw const FormatException('Invalid EUD execution rules.');
    }
    final rules = rawRules.map(EudExecutionRule.fromJson).toList();
    if (version != 3 && rules.any((r) => r.extension != null)) {
      throw const FormatException('Extended rules require schema v3.');
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
      rules: rules,
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

// Linear graph traversal keeps validation bounded for untrusted project files.
bool _hasCycle<T>(Map<T, Set<T>> graph) {
  final active = <T>{}, complete = <T>{};
  bool visit(T node) {
    if (complete.contains(node)) return false;
    if (!active.add(node)) return true;
    for (final next in graph[node] ?? <T>{}) {
      if (visit(next)) return true;
    }
    active.remove(node);
    complete.add(node);
    return false;
  }

  return graph.keys.any(visit);
}
