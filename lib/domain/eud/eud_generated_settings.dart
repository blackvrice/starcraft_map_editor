import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'eud_field_manifest.dart';
import 'eud_project.dart';
import 'eud_execution_rule.dart';

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
      '# Generated EUD settings${project.rules.isEmpty ? ' v1' : ' and execution rules v2'}. Runtime unverified.',
      '# Start once, before user onPluginStart. No current-CUnit shield writes.',
      'from eudplib import TrgUnit, Weapon, Flingy, Upgrade, Tech, TrgPlayer, Sprite, Image',
      if (project.rules.any((r) => r.enabled)) ...[
        'from eudplib import EUDVariable, EUDIf, EUDEndIf, DoActions, Accumulate, SetResources, Ore, Gas, AtLeast, AtMost, Exactly, SetTo, Add, Subtract',
        for (var i = 0; i < project.rules.length; i++)
          if (project.rules[i].enabled) '_editor_rule_$i = EUDVariable(0)',
      ],
      'def onPluginStart():',
      for (final item in operations) '    ${_assignment(item)}',
      '    print("EDITOR_SETTINGS_V1_INITIALIZED", flush=True)',
      if (project.rules.any((r) => r.enabled)) ...[
        '',
        'def beforeTriggerExec():',
        for (var i = 0; i < project.rules.length; i++)
          if (project.rules[i].enabled) ..._rule(project.rules[i], i),
      ],
    ];
    source = '${lines.join('\n')}\n';
    manifest =
        '${const JsonEncoder.withIndent('  ').convert({
          'format': 'starcraft-eud-generated-settings',
          'generatorVersion': project.rules.isEmpty ? 1 : 2,
          'runtimeStatus': 'unverified',
          'mapSha256': mapSha256,
          'projectSha256': projectSha256,
          'sourceSha256': sha256.convert(utf8.encode(source)).toString(),
          'tool': {'euddraft': EudFieldManifest.euddraftVersion, 'eudplib': EudFieldManifest.eudplibVersion},
          'hookOrder': [
            'generated.onPluginStart',
            'user.onPluginStart',
            if (project.rules.any((r) => r.enabled)) ...['generated.beforeTriggerExec (rules in list order)', 'user.beforeTriggerExec'],
            'normal triggers',
          ],
          if (project.rules.isNotEmpty) 'executionRules': project.rules.map((r) => r.toJson()).toList(),
          if (project.rules.isNotEmpty) 'rulePolicy': 'synchronized-explicit-player; periodic-first-check-after-interval; once-until-first-match; basic-Accumulate-SetResources',
          'shieldPolicy': 'type-only-no-current-unit-write',
          'operations': operations.map((o) => o.toJson()).toList(),
        })}\n';
  }
  late final String source;
  late final String manifest;
  late final String mapSha256;
  late final String projectSha256;

  static List<String> _rule(EudExecutionRule rule, int index) {
    final state = '_editor_rule_$index';
    final resource = rule.resource == EudResource.ore ? 'Ore' : 'Gas';
    final comparison = ['AtLeast', 'AtMost', 'Exactly'][rule.comparison.index];
    final operation = ['SetTo', 'Add', 'Subtract'][rule.operation.index];
    final condition =
        'Accumulate(${rule.player}, $comparison, ${rule.threshold}, $resource)';
    final action =
        'SetResources(${rule.player}, $operation, ${rule.amount}, $resource)';
    if (rule.schedule == EudRuleSchedule.once) {
      return [
        '    if EUDIf()([$state.Exactly(0), $condition]):',
        '        DoActions([$action, $state.SetNumber(1)])',
        '    EUDEndIf()',
      ];
    }
    return [
      '    DoActions($state.AddNumber(1))',
      '    if EUDIf()($state.AtLeast(${rule.interval})):',
      '        DoActions($state.SetNumber(0))',
      '        if EUDIf()($condition):',
      '            DoActions($action)',
      '        EUDEndIf()',
      '    EUDEndIf()',
    ];
  }

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
