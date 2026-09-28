import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_execution_rule.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generated_settings.dart';

EudExecutionRule rule({
  String id = 'income',
  int player = 0,
  bool enabled = true,
  EudRuleSchedule schedule = EudRuleSchedule.once,
  int interval = 24,
}) => EudExecutionRule(
  id: id,
  name: 'Income\n# not executable',
  player: player,
  resource: EudResource.ore,
  comparison: EudComparison.atMost,
  threshold: 100,
  operation: EudResourceOperation.add,
  amount: 50,
  schedule: schedule,
  interval: interval,
  enabled: enabled,
);

void main() {
  EudProject project(List<EudExecutionRule> rules) =>
      EudProject(mapPath: 'base.scx', mapSha256: 'a' * 64, rules: rules);
  test(
    'v1 remains readable and v2 preserves order, flags and rule-only content',
    () {
      final empty = project([]);
      expect(jsonDecode(empty.encode())['schemaVersion'], 1);
      expect(EudProject.decode(empty.encode()).rules, isEmpty);
      final source = project([
        rule(id: 'second', player: 1),
        rule(id: 'first', enabled: false),
      ]);
      expect(jsonDecode(source.encode())['schemaVersion'], 2);
      final loaded = EudProject.decode(source.encode());
      expect(loaded.encode(), source.encode());
      expect(loaded.hasGeneratedContent, isTrue);
      expect(loaded.rules.first.id, 'second');
      expect(loaded.rules.last.enabled, isFalse);
      expect(() => loaded.rules.clear(), throwsUnsupportedError);
      expect(loaded.withOverrides([]).rules, loaded.rules);
    },
  );
  test('rejects unsupported scope, excessive cost and duplicate identity', () {
    for (final player in [-1, 8, 13]) {
      expect(() => rule(player: player), throwsFormatException);
    }
    for (final interval in [0, 11, 86401]) {
      expect(() => rule(interval: interval), throwsFormatException);
    }
    expect(() => project([rule(), rule()]), throwsFormatException);
    expect(
      () => project(List.generate(65, (i) => rule(id: 'r$i'))),
      throwsFormatException,
    );
    expect(
      project([rule(), rule(id: 'other')]).validationIssues.single,
      contains('duplicateResourceWrite'),
    );
    expect(
      project([rule(), rule(id: 'other', enabled: false)]).validationIssues,
      isEmpty,
    );
  });
  test(
    'malformed and future rule fields cannot silently become supported rules',
    () {
      final valid = rule().toJson();
      for (final patch in <Map<String, Object>>[
        {'localPlayer': true},
        {'player': 1.0},
        {'resource': 'memory'},
        {'schedule': 'everyFrame'},
        {'amount': -1},
        {'threshold': 2147483648},
        {'enabled': 'true'},
        {'name': ''},
        {'id': 'x);exec()'},
      ]) {
        expect(
          () => EudExecutionRule.fromJson({...valid, ...patch}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'generator uses basic actions, guards once, resets periodic phase, excludes disabled rules',
    () {
      final generated = EudGeneratedSettings(
        project([
          rule(),
          rule(id: 'period', player: 1, schedule: EudRuleSchedule.periodic),
          rule(id: 'disabled', player: 2, enabled: false),
        ]),
      );
      expect(
        generated.source,
        contains(
          '[_editor_rule_0.Exactly(0), Accumulate(0, AtMost, 100, Ore)]',
        ),
      );
      expect(
        generated.source,
        contains(
          'DoActions([SetResources(0, Add, 50, Ore), _editor_rule_0.SetNumber(1)])',
        ),
      );
      expect(
        generated.source,
        contains('DoActions(_editor_rule_1.AddNumber(1))'),
      );
      expect(
        generated.source.indexOf('_editor_rule_1.SetNumber(0)'),
        lessThan(generated.source.indexOf('Accumulate(1,')),
      );
      expect(generated.source, isNot(contains('_editor_rule_2')));
      expect(generated.source, isNot(contains('not executable')));
      expect(jsonDecode(generated.manifest)['executionRules'], hasLength(3));
      expect(
        () => EudGeneratedSettings(project([rule(), rule(id: 'duplicate')])),
        throwsFormatException,
      );
    },
  );
}
