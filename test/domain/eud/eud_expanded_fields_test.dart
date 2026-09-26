import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_field_manifest.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generation_preview.dart';
import 'package:starcraft_map_editor/domain/eud/eud_override_impact.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import '../../fixtures/eud_impact_fixture.dart';

EudProject project(List<EudOverride> overrides) =>
    EudProject(mapPath: 'map.scx', mapSha256: 'a' * 64, overrides: overrides);

void main() {
  test('all eight categories validate types, target and value boundaries', () {
    expect(
      EudFieldManifest.fields.map((f) => f.table).toSet(),
      EudTable.values.toSet(),
    );
    for (final field in EudFieldManifest.fields) {
      final Object value = switch (field.type) {
        EudValueType.boolean => false,
        EudValueType.enumeration => field.choices.last,
        EudValueType.unsignedInteger => field.allowedBits ?? field.valueMaximum,
      };
      expect(field.validate(0, value), isNull, reason: field.key);
      expect(
        field.validate(field.targetCount - 1, value),
        isNull,
        reason: field.key,
      );
      expect(
        field.validate(field.targetCount, value),
        EudFieldError.invalidTarget,
      );
      expect(field.validate(0, null), EudFieldError.invalidType);
      if (field.type == EudValueType.unsignedInteger) {
        expect(
          field.validate(0, field.valueMaximum + 1),
          EudFieldError.outOfRange,
        );
        expect(field.validate(0, -1), EudFieldError.outOfRange);
        expect(field.validate(0, 0.5), EudFieldError.invalidType);
      }
    }
  });
  test(
    'reference bounds, partial sound tables and reserved flags are rejected',
    () {
      expect(EudFieldManifest.validate('unit.groundWeapon', 227, 130), isNull);
      expect(
        EudFieldManifest.validate('unit.groundWeapon', 0, 131),
        EudFieldError.outOfRange,
      );
      expect(
        EudFieldManifest.validate('unit.readySound', 106, 0),
        EudFieldError.invalidTarget,
      );
      expect(EudFieldManifest.validate('unit.whatSoundEnd', 227, 1143), isNull);
      expect(
        EudFieldManifest.validate('unit.portrait', 0, 110),
        EudFieldError.outOfRange,
      );
      expect(
        EudFieldManifest.validate('unit.baseProperty', 0, 0x40000),
        EudFieldError.outOfRange,
      );
      expect(
        EudFieldManifest.validate('weapon.targetFlags', 0, 0x200),
        EudFieldError.outOfRange,
      );
      expect(
        EudFieldManifest.validate('image.drawingFunction', 0, 'HpBar'),
        EudFieldError.invalidEnum,
      );
      expect(
        EudFieldManifest.validate('weapon.explosionType', 0, 'Unknown_Crash'),
        EudFieldError.invalidEnum,
      );
      expect(
        EudFieldManifest.validate('player.protossPsiMax', 8, 400),
        EudFieldError.invalidTarget,
      );
    },
  );
  test(
    'all categories round-trip and produce deterministic non-executable preview',
    () {
      final overrides = [
        for (final field in EudFieldManifest.fields)
          EudOverride(
            field: field.key,
            targetId: 0,
            value: switch (field.type) {
              EudValueType.boolean => true,
              EudValueType.enumeration => field.choices.first,
              EudValueType.unsignedInteger => 0,
            },
            overrideChk: field.overlapsChk,
          ),
      ];
      final original = project(overrides);
      expect(original.validationIssues, isEmpty);
      final decoded = EudProject.decode(original.encode());
      expect(decoded.encode(), original.encode());
      final preview = EudGenerationPreview(decoded).manifest;
      expect(
        preview,
        EudGenerationPreview(project(overrides.reversed.toList())).manifest,
      );
      final json = jsonDecode(preview) as Map<String, dynamic>;
      expect(json['executable'], false);
      expect(json['operations'], hasLength(overrides.length));
    },
  );
  test('CHK overlap requires explicit opt-in for every affected field', () {
    for (final field in EudFieldManifest.fields.where((f) => f.overlapsChk)) {
      final p = project([EudOverride(field: field.key, targetId: 0, value: 1)]);
      expect(
        p.validationIssues.single,
        endsWith('explicitChkOverrideRequired'),
      );
    }
  });
  test('partial splash and sound ranges cannot contradict each other', () {
    for (final pair in [
      ('weapon.splashInnerRadius', 'weapon.splashOuterRadius'),
      ('weapon.splashInnerRadius', 'weapon.splashMiddleRadius'),
      ('weapon.splashMiddleRadius', 'weapon.splashOuterRadius'),
      ('unit.whatSoundStart', 'unit.whatSoundEnd'),
      ('unit.pissedSoundStart', 'unit.pissedSoundEnd'),
      ('unit.yesSoundStart', 'unit.yesSoundEnd'),
    ]) {
      expect(
        project([
          EudOverride(field: pair.$1, targetId: 0, value: 2),
          EudOverride(field: pair.$2, targetId: 0, value: 1),
        ]).validationIssues.single,
        contains(':exceeds:'),
      );
      expect(
        project([
          EudOverride(field: pair.$1, targetId: 0, value: 2),
          EudOverride(field: pair.$2, targetId: 1, value: 1),
        ]).validationIssues,
        isEmpty,
      );
    }
  });
  test('new tables never reuse weapon references as false unit impacts', () {
    for (final key in [
      'flingy.topSpeed',
      'upgrade.maxLevel',
      'tech.energyCost',
      'player.terranSupplyMax',
      'sprite.image',
      'image.isClickable',
    ]) {
      final result = EudOverrideImpact.analyze(
        EudOverride(
          field: key,
          targetId: 5,
          value: key == 'image.isClickable' ? true : 1,
        ),
        references: impactReferences(),
      );
      expect(result.error, isNull);
      expect(result.directUnits, isNull, reason: key);
      expect(result.subunitUnits, isNull);
    }
  });
}
