import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generation_preview.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';

void main() {
  EudProject project(List<EudOverride> overrides) => EudProject(
    mapPath: 'input.scx',
    mapSha256: 'a' * 64,
    overrides: overrides,
  );
  test('preview is deterministic and remains explicitly non-executable', () {
    final fields = [
      EudOverride(field: 'weapon.maxRange', targetId: 7, value: 128),
      EudOverride(field: 'unit.hasShield', targetId: 1, value: true),
      EudOverride(field: 'weapon.minRange', targetId: 7, value: 0),
      EudOverride(
        field: 'unit.maxShield',
        targetId: 1,
        value: 80,
        overrideChk: true,
      ),
      EudOverride(field: 'weapon.damageType', targetId: 7, value: 'Normal'),
    ];
    final input = project(fields);
    final before = input.encode();
    final text = EudGenerationPreview(input).manifest;
    expect(
      text,
      EudGenerationPreview(project(fields.reversed.toList())).manifest,
    );
    expect(input.encode(), before);
    final manifest = jsonDecode(text) as Map;
    expect(manifest['executable'], isFalse);
    expect(manifest['runtimeStatus'], 'unverified');
    expect(manifest['operations'], hasLength(5));
    expect((manifest['operations'] as List).first['table'], 'unit');
  });
  test(
    'invalid, future, conflicting and undeclared CHK overrides are rejected',
    () {
      for (final overrides in [
        [EudOverride(field: 'unit.future', targetId: 0, value: 1)],
        [EudOverride(field: 'unit.maxShield', targetId: 0, value: 20)],
        [
          EudOverride(
            field: 'weapon.damageType',
            targetId: 0,
            value: '__import__',
          ),
        ],
        [
          EudOverride(field: 'weapon.minRange', targetId: 0, value: 9),
          EudOverride(field: 'weapon.maxRange', targetId: 0, value: 8),
        ],
      ]) {
        expect(
          () => EudGenerationPreview(project(overrides)),
          throwsFormatException,
        );
      }
    },
  );
}
