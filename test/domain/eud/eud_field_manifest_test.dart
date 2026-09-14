import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_field_manifest.dart';

void main() {
  test(
    'unknown fields and pseudo targets never pass structural validation',
    () {
      expect(
        EudFieldManifest.validate('weapon.address', 0, 10),
        EudFieldError.unknownField,
      );
      for (final field in EudFieldManifest.fields) {
        expect(field.validate(-1, null), EudFieldError.invalidTarget);
        expect(
          field.validate(field.targetCount, null),
          EudFieldError.invalidTarget,
        );
      }
      expect(
        EudFieldManifest.validate('weapon.maxRange', 130, 100),
        EudFieldError.invalidTarget,
      );
      expect(
        EudFieldManifest.validate('unit.hasShield', 228, true),
        EudFieldError.invalidTarget,
      );
    },
  );

  test('unsigned storage bounds reject overflow, fractions and strings', () {
    for (final key in [
      'unit.maxShield',
      'weapon.minRange',
      'weapon.maxRange',
    ]) {
      final field = EudFieldManifest.find(key)!;
      expect(field.validate(0, 0), isNull);
      expect(
        field.validate(field.targetCount - 1, field.storageMaximum),
        isNull,
      );
      expect(field.validate(0, -1), EudFieldError.outOfRange);
      expect(
        field.validate(0, field.storageMaximum + 1),
        EudFieldError.outOfRange,
      );
      for (final value in [null, true, '32', 1.5, 32.0]) {
        expect(field.validate(0, value), EudFieldError.invalidType);
      }
    }
    expect(EudFieldManifest.find('unit.maxShield')!.storageMaximum, 65535);
    expect(
      EudFieldManifest.find('weapon.maxRange')!.storageMaximum,
      4294967295,
    );
  });

  test('shield enablement requires an explicit boolean', () {
    for (final value in [true, false]) {
      expect(EudFieldManifest.validate('unit.hasShield', 0, value), isNull);
    }
    for (final value in [0, 1, 'true', null]) {
      expect(
        EudFieldManifest.validate('unit.hasShield', 0, value),
        EudFieldError.invalidType,
      );
    }
  });

  test(
    'damage enum uses exact SCData symbols without guessing numeric values',
    () {
      for (final value in [
        'Independent',
        'Explosive',
        'Concussive',
        'Normal',
        'IgnoreArmor',
      ]) {
        expect(
          EudFieldManifest.validate('weapon.damageType', 0, value),
          isNull,
        );
      }
      for (final value in ['normal', 'Splash', '']) {
        expect(
          EudFieldManifest.validate('weapon.damageType', 0, value),
          EudFieldError.invalidEnum,
        );
      }
      expect(
        EudFieldManifest.validate('weapon.damageType', 0, 3),
        EudFieldError.invalidType,
      );
    },
  );

  test(
    'metadata retains CHK overlap, shared impact and unresolved distance units',
    () {
      expect(EudFieldManifest.find('unit.maxShield')!.overlapsChk, isTrue);
      expect(
        EudFieldManifest.find('weapon.maxRange')!.requiresWeaponImpactAnalysis,
        isTrue,
      );
      expect(
        EudFieldManifest.find('weapon.maxRange')!.unit,
        EudFieldUnit.rawDistance,
      );
      final keys = EudFieldManifest.fields.map((field) => field.key).toSet();
      expect(keys.length, EudFieldManifest.fields.length);
      for (final field in EudFieldManifest.fields) {
        expect(keys.containsAll(field.relatedFields), isTrue);
      }
      expect(() => EudFieldManifest.fields.clear(), throwsUnsupportedError);
    },
  );

  test('matching source versions still do not imply runtime support', () {
    expect(
      EudFieldManifest.compatibility(euddraft: '0.10.2.5', eudplib: '0.80.6'),
      EudCompatibility.runtimeUnverified,
    );
    expect(EudFieldManifest.verifiedGameBuilds, isEmpty);
    for (final versions in [
      ('0.10.2.6', '0.80.6'),
      ('0.10.2.5', '0.81.0'),
      ('', ''),
    ]) {
      expect(
        EudFieldManifest.compatibility(
          euddraft: versions.$1,
          eudplib: versions.$2,
        ),
        EudCompatibility.toolVersionMismatch,
      );
    }
  });
}
