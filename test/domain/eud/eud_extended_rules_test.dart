import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_execution_rule.dart';
import 'package:starcraft_map_editor/domain/eud/eud_rule_expression.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generated_settings.dart';
import 'package:starcraft_map_editor/domain/eud/eud_rule_references.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_document.dart';

EudExecutionRule extendedRule(
  EudRuleAction action, {
  int target = 0,
  int variable = 1,
  String id = 'extended',
  EudRuleTiming timing = EudRuleTiming.beforeTriggers,
}) => EudExecutionRule(
  id: id,
  name: id,
  player: 0,
  resource: EudResource.ore,
  comparison: EudComparison.atLeast,
  threshold: 0,
  operation: EudResourceOperation.setTo,
  amount: 0,
  extension: EudRuleExtension(
    action: action,
    target: target,
    timing: timing,
    left: EudRuleValue(),
    right: EudRuleValue(),
    value: EudRuleValue(source: EudValueSource.variable, index: variable),
    coordinates: action == EudRuleAction.location
        ? List.generate(4, (_) => EudRuleValue(index: 32))
        : [],
  ),
);

void main() {
  EudProject project(List<EudExecutionRule> rules) =>
      EudProject(mapPath: 'base.scx', mapSha256: 'a' * 64, rules: rules);
  test(
    'extended schema survives every action and refuses accidental downgrade',
    () {
      for (final action in EudRuleAction.values) {
        final target =
            {
              EudRuleAction.location,
              EudRuleAction.followUnit,
              EudRuleAction.sound,
            }.contains(action)
            ? 1
            : 0;
        final p = project([extendedRule(action, target: target)]);
        expect(EudProject.decode(p.encode()).encode(), p.encode());
        final data = jsonDecode(p.encode()) as Map<String, dynamic>;
        expect(data['schemaVersion'], 3);
        data['schemaVersion'] = 2;
        expect(
          () => EudProject.decode(jsonEncode(data)),
          throwsFormatException,
        );
      }
    },
  );
  test('bounds and unknown/local operands are rejected', () {
    for (final values in [
      {
        'source': 'localPlayer',
        'index': 0,
        'player': 0,
        'factor': 1,
        'offset': 0,
      },
      {
        'source': 'variable',
        'index': 16,
        'player': 0,
        'factor': 1,
        'offset': 0,
      },
      {
        'source': 'constant',
        'index': 65536,
        'player': 0,
        'factor': 1,
        'offset': 0,
      },
      {'source': 'gas', 'index': 0, 'player': 8, 'factor': 1, 'offset': 0},
      {
        'source': 'constant',
        'index': 0,
        'player': 0,
        'factor': 256,
        'offset': 0,
      },
    ]) {
      expect(() => EudRuleValue.decode(values), throwsFormatException);
    }
    expect(
      () => extendedRule(EudRuleAction.location, target: 64),
      throwsFormatException,
    );
    expect(() => extendedRule(EudRuleAction.sound), throwsFormatException);
  });
  test(
    'cycles, shared location writes and repeated unit scans are blocked',
    () {
      expect(
        project([
          extendedRule(EudRuleAction.variable, target: 0, variable: 1),
          extendedRule(
            EudRuleAction.variable,
            id: 'back',
            target: 1,
            variable: 0,
          ),
        ]).validationIssues,
        contains('cyclicVariableRules'),
      );
      expect(
        project([
          extendedRule(EudRuleAction.location, target: 1),
          extendedRule(EudRuleAction.followUnit, target: 1, id: 'follow'),
        ]).validationIssues.single,
        contains('duplicateResourceWrite'),
      );
      final rules = List.generate(
        5,
        (i) => extendedRule(EudRuleAction.followUnit, target: i + 1, id: 'r$i'),
      );
      expect(
        project(rules).validationIssues,
        contains('unitScanBudgetExceeded:4'),
      );
    },
  );
  test(
    'local display follows synchronized latch and cannot write a game target',
    () {
      final source = EudGeneratedSettings(
        project([
          extendedRule(EudRuleAction.text, timing: EudRuleTiming.afterTriggers),
        ]),
      ).source;
      expect(source, contains('def afterTriggerExec():'));
      expect(
        source.indexOf('DoActions(_editor_rule_0.SetNumber(1))'),
        lessThan(source.indexOf('if EUDIf()(f_getuserplayerid()')),
      );
      expect(source, contains('f_setcurpl(_old_cp)'));
      expect(source, isNot(contains('SetResources(0,')));
    },
  );
  test(
    'instance writes use scanned units with identity and lifecycle guards',
    () {
      final source = EudGeneratedSettings(
        project([extendedRule(EudRuleAction.unitHp)]),
      ).source;
      expect(source, contains('found << 0'));
      expect(source, contains('unit.order >= 1, unit.hp >= 1'));
      expect(
        source,
        contains('identity == epd, generation == unit.uniquenessIdentifier'),
      );
      expect(source, contains('status << 2'));
      expect(source, contains('unit.hp = amount'));
      expect(source, isNot(contains('TrgUnit(0).maxHp =')));
    },
  );
  test('map-dependent locations and sounds reject missing sections', () {
    final document = RawChkDocument(sections: [], sourceLength: 0);
    expect(
      EudRuleReferences.validate(
        project([extendedRule(EudRuleAction.location, target: 1)]),
        document,
      ).single,
      contains('unavailableLocation'),
    );
    expect(
      EudRuleReferences.validate(
        project([extendedRule(EudRuleAction.sound, target: 1)]),
        document,
      ).single,
      contains('ambiguousSoundTable'),
    );
  });
}
