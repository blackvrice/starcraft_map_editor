import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generated_settings.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';

void main() {
  EudProject project(List<EudOverride> values) => EudProject(
    mapPath: r'C:\maps\base.scx',
    mapSha256: 'a' * 64,
    overrides: values,
  );
  test('deterministic typed assignments never inject keys or enum strings', () {
    final values = [
      EudOverride(field: 'unit.hasShield', targetId: 8, value: true),
      EudOverride(field: 'weapon.damageType', targetId: 15, value: 'Normal'),
      EudOverride(
        field: 'unit.maxShield',
        targetId: 8,
        value: 100,
        overrideChk: true,
      ),
    ];
    final generated = EudGeneratedSettings(project(values));
    expect(
      generated.source,
      EudGeneratedSettings(project(values.reversed.toList())).source,
    );
    expect(
      generated.manifest,
      EudGeneratedSettings(project(values.reversed.toList())).manifest,
    );
    expect(generated.source, contains('TrgUnit(8).hasShield = True'));
    expect(generated.source, contains('Weapon(15).damageType = "Normal"'));
    expect(generated.source, isNot(contains('beforeTriggerExec')));
    expect(generated.source, isNot(contains('CUnit(')));
    expect(
      jsonDecode(generated.manifest)['shieldPolicy'],
      'type-only-no-current-unit-write',
    );
    for (final invalid in [
      EudOverride(
        field: 'weapon.damageType',
        targetId: 0,
        value: 'Normal"; evil()',
      ),
      EudOverride(field: 'unit.maxShield', targetId: 0, value: 100),
      EudOverride(field: 'unit.unknown', targetId: 0, value: 1),
    ]) {
      expect(
        () => EudGeneratedSettings(project([invalid])),
        throwsFormatException,
      );
    }
  });
}
