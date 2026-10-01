import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_document.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_section.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/domain/eud/eud_execution_rule.dart';
import 'package:starcraft_map_editor/domain/eud/eud_conflict_analysis.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generated_settings.dart';
import 'package:starcraft_map_editor/domain/eud/eud_rule_expression.dart';

RawChkDocument doc(List<ChkTrigger> triggers) {
  final bytes = ChkTriggers.encode(triggers);
  return RawChkDocument(
    sourceLength: bytes.length + 8,
    sections: [
      RawChkSection(
        nameBytes: 'TRIG'.codeUnits,
        declaredLength: bytes.length,
        payload: bytes,
        sourceOffset: 0,
      ),
    ],
  );
}

EudProject project({List<EudExecutionRule> rules = const []}) => EudProject(
  mapPath: 'test.scx',
  mapSha256: 'a' * 64,
  overrides: [
    EudOverride(field: 'weapon.cooldown', targetId: 0, value: 1),
    EudOverride(
      field: 'unit.maxShield',
      targetId: 0,
      value: 100,
      overrideChk: true,
    ),
  ],
  rules: rules,
);
List<int> memorySlot(bool action, int address, {int? mask}) {
  final b = Uint8List(action ? 32 : 20), d = ByteData.sublistView(b);
  b[action ? 26 : 15] = action ? 45 : 15;
  d.setUint32(
    action ? 16 : 4,
    ((address - 0x58a364) ~/ 4) & 0xffffffff,
    Endian.little,
  );
  if (mask != null) {
    d.setUint32(0, mask, Endian.little);
    d.setUint16(action ? 30 : 18, 0x4353, Endian.little);
  }
  return b;
}

void main() {
  test(
    'unit property actions report shared writes conservatively across locations and groups',
    () {
      for (final (type, action) in [
        (49, EudRuleAction.unitHp),
        (50, EudRuleAction.unitEnergy),
        (51, EudRuleAction.unitShields),
      ]) {
        final rule = EudExecutionRule(
          id: 'unit',
          name: 'unit',
          player: 0,
          resource: EudResource.ore,
          comparison: EudComparison.atLeast,
          threshold: 0,
          operation: EudResourceOperation.setTo,
          amount: 0,
          extension: EudRuleExtension(
            action: action,
            left: EudRuleValue(),
            right: EudRuleValue(),
            value: EudRuleValue(),
            unitType: 0,
          ),
        );
        final slot = Uint8List(32)..[26] = type;
        final report = EudConflictAnalysis.analyze(
          project(rules: [rule]),
          document: doc([ChkTrigger.create().withSlot(true, 0, slot)]),
        );
        expect(
          report.where((c) => c.kind == EudConflictKind.ruleWrite),
          hasLength(1),
        );
      }
      expect(
        () => EudConflictAnalysis.analyze(
          project(),
          userSource:
              'Weapon(9999999999999999999999999999999).cooldown = 1; SetMemory(99999999999999999999999999, SetTo, 1);',
        ),
        returnsNormally,
      );
    },
  );
  test(
    'EUD deaths reads/writes detect byte, word and masked dword overlap without edits',
    () {
      final t = ChkTrigger.create()
          .withSlot(true, 0, memorySlot(true, 0x656fb8))
          .withSlot(false, 0, memorySlot(false, 0x656fb8))
          .withSlot(true, 1, memorySlot(true, 0x660e00, mask: 0xffff));
      final map = doc([t]), before = map.sections.single.payload.toList();
      final report = EudConflictAnalysis.analyze(project(), document: map);
      expect(
        report
            .where((r) => r.kind == EudConflictKind.memoryWrite)
            .map((r) => r.target),
        contains('weapon.cooldown:0'),
      );
      expect(
        report
            .where((r) => r.kind == EudConflictKind.memoryWrite)
            .map((r) => r.target),
        contains('unit.maxShield:0'),
      );
      expect(
        report.where((r) => r.kind == EudConflictKind.memoryRead),
        hasLength(1),
      );
      expect(
        EudConflictAnalysis.analyze(
          project(),
          document: doc([t.withEnabled(false)]),
        ).where((r) => r.kind != EudConflictKind.unresolved),
        isEmpty,
      );
      final ignored = t
          .withSlot(true, 0, memorySlot(true, 0x656fb8, mask: 0xffffff00))
          .withSlot(false, 0, List.filled(20, 0))
          .withSlot(true, 1, List.filled(32, 0));
      expect(
        EudConflictAnalysis.analyze(
          project(),
          document: doc([ignored]),
        ).where((r) => r.kind == EudConflictKind.memoryWrite),
        isEmpty,
      );
      expect(map.sections.single.payload, before);
      expect(map.isDirty, isFalse);
    },
  );
  test(
    'resource rule conflicts, inactive slots and malformed duplicate TRIG stay conservative',
    () {
      final rule = EudExecutionRule(
        id: 'ore',
        name: 'ore',
        player: 0,
        resource: EudResource.ore,
        comparison: EudComparison.atLeast,
        threshold: 0,
        operation: EudResourceOperation.setTo,
        amount: 50,
        schedule: EudRuleSchedule.once,
        interval: 12,
      );
      final slot = Uint8List(32)..[26] = 26;
      final map = doc([ChkTrigger.create().withSlot(true, 0, slot)]);
      expect(
        EudConflictAnalysis.analyze(
          project(rules: [rule]),
          document: map,
        ).where((r) => r.kind == EudConflictKind.ruleWrite),
        hasLength(1),
      );
      slot[28] = 2;
      expect(
        EudConflictAnalysis.analyze(
          project(rules: [rule]),
          document: doc([ChkTrigger.create().withSlot(true, 0, slot)]),
        ).where((r) => r.kind == EudConflictKind.ruleWrite),
        isEmpty,
      );
      final duplicate = map.appendSection(map.sections.single);
      expect(
        EudConflictAnalysis.analyze(project(), document: duplicate).any(
          (r) => r.origin == 'TRIG' && r.kind == EudConflictKind.unresolved,
        ),
        isTrue,
      );
    },
  );
  test(
    'literal Python/epScript writes ignore comments/strings but never certify arbitrary code',
    () {
      const code = '''# Weapon(0).cooldown = 100
"Weapon(0).cooldown = 100"
/* SetMemory(0x656fb8, SetTo, 100); */
Weapon(0).cooldown = 1;
SetMemoryEPD(209685, SetTo, 1);
SetMemoryX(0x656fb8, SetTo, 1, 0xff);
Weapon(dynamic_id).cooldown = value;
''';
      final report = EudConflictAnalysis.analyze(
        project(),
        document: doc([]),
        userSource: code,
      );
      expect(
        report.where((r) => r.kind == EudConflictKind.sourceWrite).first.origin,
        'source:4',
      );
      expect(
        report.where((r) => r.kind == EudConflictKind.sourceWrite),
        hasLength(3),
      );
      expect(
        report.where((r) => r.kind == EudConflictKind.unresolved),
        isNotEmpty,
      );
      final generated = EudGeneratedSettings(project(), conflicts: report);
      expect(generated.manifest, contains('staticConflictAnalysis'));
      expect(generated.source, EudGeneratedSettings(project()).source);
    },
  );
}
