import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';

void main() {
  final hash = 'a' * 64;
  EudProject project(List<EudOverride> values) => EudProject(
    mapPath: r'C:\maps\한글.scx',
    mapSha256: hash,
    overrides: values,
  );
  EudOverride value(
    String field,
    Object value, {
    int id = 0,
    bool override = false,
  }) => EudOverride(
    field: field,
    targetId: id,
    value: value,
    overrideChk: override,
  );

  test(
    'all five fields round trip deterministically without executing anything',
    () {
      final entries = [
        value('unit.hasShield', true),
        value('unit.maxShield', 500, override: true),
        value('weapon.minRange', 0),
        value('weapon.maxRange', 256),
        value('weapon.damageType', 'Normal'),
      ];
      final encoded = project(entries).encode();
      final decoded = EudProject.decode(encoded);
      expect(decoded.validationIssues, isEmpty);
      expect(decoded.encode(), encoded);
      expect(project(entries.reversed.toList()).encode(), encoded);
      expect(decoded.mapPath, r'C:\maps\한글.scx');
      expect(decoded.mapSha256, hash);
      expect(() => decoded.overrides.clear(), throwsUnsupportedError);
    },
  );

  test('unknown fields survive round trip and remain diagnosed', () {
    final original = project([value('weapon.futureField', 'Future')]);
    final restored = EudProject.decode(original.encode());
    expect(restored.encode(), original.encode());
    expect(restored.validationIssues.single, contains('unknownField'));
  });

  test('CHK override must be explicit and min/max pair is checked', () {
    expect(
      project([value('unit.maxShield', 10)]).validationIssues.single,
      contains('explicitChkOverrideRequired'),
    );
    expect(
      project([
        value('weapon.minRange', 300),
        value('weapon.maxRange', 100),
      ]).validationIssues.single,
      contains('minimumExceedsMaximum'),
    );
    expect(
      project([
        value('weapon.minRange', 300),
        value('weapon.maxRange', 100, id: 1),
      ]).validationIssues,
      isEmpty,
    );
    expect(
      project([value('weapon.maxRange', -1)]).validationIssues.single,
      contains('outOfRange'),
    );
  });

  test(
    'duplicate assignments are rejected instead of silently selecting a value',
    () {
      expect(
        () => project([
          value('unit.hasShield', true),
          value('unit.hasShield', false),
        ]),
        throwsFormatException,
      );
    },
  );

  test('future schema, extra properties and wrong types are refused', () {
    final original = project([]).encode();
    for (final version in [0, 2, '1', 1.0]) {
      final root = jsonDecode(original) as Map<String, dynamic>;
      root['schemaVersion'] = version;
      expect(() => EudProject.decode(jsonEncode(root)), throwsFormatException);
    }
    final root = jsonDecode(original) as Map<String, dynamic>;
    root['future'] = true;
    expect(() => EudProject.decode(jsonEncode(root)), throwsFormatException);
    root.remove('future');
    root['overrides'] = [
      {
        'field': 'unit.hasShield',
        'targetId': 0.0,
        'value': true,
        'overrideChk': false,
      },
    ];
    expect(() => EudProject.decode(jsonEncode(root)), throwsFormatException);
    expect(() => EudProject.decode('{'), throwsFormatException);
    expect(
      () => EudProject.decode(' ' * (EudProject.maxTextLength + 1)),
      throwsFormatException,
    );
    expect(
      () => EudProject(mapPath: 'map.scx', mapSha256: 'broken'),
      throwsFormatException,
    );
  });
}
