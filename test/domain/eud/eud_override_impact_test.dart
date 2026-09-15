import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_field_manifest.dart';
import 'package:starcraft_map_editor/domain/eud/eud_override_impact.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import '../../fixtures/eud_impact_fixture.dart';

void main() {
  test('shared weapon impact deduplicates direct and cyclic subunit users', () {
    final impact = EudOverrideImpact.analyze(
      EudOverride(field: 'weapon.maxRange', targetId: 5, value: 64),
      references: impactReferences(),
    );
    expect(impact.error, isNull);
    expect(impact.directUnits, [0, 1]);
    expect(impact.subunitUnits, [2, 3]);
    expect(() => impact.directUnits!.add(4), throwsUnsupportedError);
  });
  test('unknown references differ from a verified empty weapon', () {
    final item = EudOverride(field: 'weapon.minRange', targetId: 129, value: 0);
    expect(EudOverrideImpact.analyze(item).directUnits, isNull);
    expect(
      EudOverrideImpact.analyze(
        item,
        references: impactReferences(),
      ).directUnits,
      isEmpty,
    );
    expect(
      EudOverrideImpact.analyze(
        EudOverride(field: 'unit.hasShield', targetId: 227, value: true),
      ).directUnits,
      [227],
    );
  });
  test('preserved unknown fields and invalid targets cannot claim impact', () {
    for (final pair in [
      (
        EudOverride(field: 'weapon.future', targetId: 0, value: 1),
        EudFieldError.unknownField,
      ),
      (
        EudOverride(field: 'weapon.maxRange', targetId: 130, value: 1),
        EudFieldError.invalidTarget,
      ),
      (
        EudOverride(field: 'unit.hasShield', targetId: 0, value: 1),
        EudFieldError.invalidType,
      ),
    ]) {
      final impact = EudOverrideImpact.analyze(
        pair.$1,
        references: impactReferences(),
      );
      expect(impact.error, pair.$2);
      expect(impact.directUnits, isNull);
    }
  });
}
