import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'eud_field_manifest.dart';
import 'eud_project.dart';

/// Deterministic compiler input. Compilable does not mean game verified.
final class EudGeneratedSettings {
  EudGeneratedSettings(EudProject project) {
    final issues = project.validationIssues;
    if (issues.isNotEmpty) throw FormatException(issues.join(', '));
    mapSha256 = project.mapSha256;
    projectSha256 = sha256.convert(utf8.encode(project.encode())).toString();
    final operations = [...project.overrides]
      ..sort((a, b) {
        final field = a.field.compareTo(b.field);
        return field != 0 ? field : a.targetId.compareTo(b.targetId);
      });
    final lines = <String>[
      '# Generated EUD settings v1. Runtime unverified.',
      '# Start once, before user onPluginStart. No current-CUnit shield writes.',
      'from eudplib import TrgUnit, Weapon, Flingy, Upgrade, Tech, TrgPlayer, Sprite, Image',
      'def onPluginStart():',
      for (final item in operations) '    ${_assignment(item)}',
      '    print("EDITOR_SETTINGS_V1_INITIALIZED", flush=True)',
    ];
    source = '${lines.join('\n')}\n';
    manifest =
        '${const JsonEncoder.withIndent('  ').convert({
          'format': 'starcraft-eud-generated-settings',
          'generatorVersion': 1,
          'runtimeStatus': 'unverified',
          'mapSha256': mapSha256,
          'projectSha256': projectSha256,
          'sourceSha256': sha256.convert(utf8.encode(source)).toString(),
          'tool': {'euddraft': EudFieldManifest.euddraftVersion, 'eudplib': EudFieldManifest.eudplibVersion},
          'hookOrder': ['generated.onPluginStart', 'user.onPluginStart', 'normal triggers'],
          'shieldPolicy': 'type-only-no-current-unit-write',
          'operations': operations.map((o) => o.toJson()).toList(),
        })}\n';
  }
  late final String source;
  late final String manifest;
  late final String mapSha256;
  late final String projectSha256;

  static String _assignment(EudOverride item) {
    final field = EudFieldManifest.find(item.field)!;
    final member = field.member.split('.');
    final value = item.value;
    final literal = value is bool
        ? (value ? 'True' : 'False')
        : jsonEncode(value);
    return '${member[0]}(${item.targetId}).${member[1]} = $literal';
  }
}
