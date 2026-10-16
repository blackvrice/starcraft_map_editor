import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_player_colors.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_string_tokens.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_search.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_settings_defaults.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_unit_settings_editor.dart';
import '../../fixtures/settings_trigger_editing_fixture.dart';
import '../../fixtures/eud_dat_fixture.dart';

void main() {
  test('search filters owner enabled and slot kind independently', () {
    final doc = editingDocument();
    final search = ChkTriggerSearch(
      withRecords(doc, [
        triggerAction(doc, 9),
        triggerAction(
          doc,
          10,
        ).withEnabled(false).withOwner(0, false).withOwner(1, true),
        ChkTrigger.create(),
      ]),
    );
    expect(search.find('', owner: 1), [1]);
    expect(search.find('', enabled: false), [1]);
    expect(search.find('', action: true), [0, 1]);
    expect(search.find('', action: true, opcode: 10), [1]);
    expect(search.find('', action: false, opcode: 23), [0, 1, 2]);
    expect(search.find('', owner: 30), isEmpty);
  });
  test(
    'unknown unchanged color is a no-op and cannot become a new palette ID',
    () {
      var doc = ChkPlayerColors.edit(editingDocument(), {
        0: const ChkPlayerColor(2, 1, 2, 20),
      });
      expect(
        () => ChkPlayerColors.edit(doc, {0: const ChkPlayerColor(3, 1, 2, 20)}),
        throwsFormatException,
      );
      final bytes = doc.sections.last.payload.toList()..[24] = 99;
      doc = doc.replaceSection(
        doc.sections.length - 1,
        doc.sections.last.withPayload(bytes),
      );
      expect(
        ChkPlayerColors.edit(doc, {0: const ChkPlayerColor(99, 1, 2, 20)}),
        same(doc),
      );
    },
  );
  test(
    'tokens roundtrip every non-NUL byte and Unicode without substitution',
    () {
      for (final raw in [
        List.generate(255, (i) => i + 1),
        utf8.encode('한글 <06> << 😀'),
        [0xe0, 0x80, 0xff, 6, 65, 10],
      ]) {
        expect(ChkStringTokens.decode(ChkStringTokens.encode(raw)), raw);
      }
      expect(ChkStringTokens.decode('<<06><06>A'), [60, 48, 54, 62, 6, 65]);
    },
  );
  for (final invalid in [
    '<00>',
    '\u0000',
    '<0>',
    '<GG>',
    '<',
    '<001>',
    '<FF',
  ]) {
    test(
      'tokens reject malformed or NUL input ${invalid.codeUnits}',
      () =>
          expect(() => ChkStringTokens.decode(invalid), throwsFormatException),
    );
  }
  test('raw token edits preserve IDs shared references and unedited bytes', () {
    final doc = editingDocument();
    final raw = [6, ...utf8.encode('경고'), 0xff, 10, 60];
    final before = const RawChkEncoder().encode(doc);
    final refs = ChkResourceEditor.references(
      doc,
    ).uses.where((u) => u.id == 1).toList();
    final edited = ChkResourceEditor.editRaw(doc, 1, raw);
    expect(ChkResourceEditor.table(edited).entryForId(1)!.rawBytes, raw);
    expect(
      ChkResourceEditor.references(edited).uses.where((u) => u.id == 1).length,
      refs.length,
    );
    final split = ChkResourceEditor.editRaw(doc, 1, raw, onlyUse: refs.first);
    expect(
      ChkResourceEditor.table(split).entryForId(1)!.rawBytes,
      utf8.encode('Mission Alpha'),
    );
    expect(ChkResourceEditor.table(split).entries.last.rawBytes, raw);
    expect(const RawChkEncoder().encode(doc), before);
    for (var i = 0; i < doc.sections.length; i++) {
      if (doc.sections[i].name != 'STR ') {
        expect(edited.sections[i], same(doc.sections[i]));
      }
    }
    expect(() => ChkResourceEditor.addRaw(doc, [0]), throwsFormatException);
    expect(
      () => ChkResourceEditor.editRaw(doc, 1, [256]),
      throwsFormatException,
    );
  });
  test(
    'CRGB four modes and explicit VER upgrade preserve COLR and other bytes',
    () {
      final doc = editingDocument();
      final edited = ChkPlayerColors.edit(doc, {
        for (var i = 0; i < 4; i++) i: ChkPlayerColor(i, 10, 20, 3),
      });
      final colors = ChkPlayerColors.read(edited);
      expect(colors.map((c) => c.mode), [0, 1, 2, 3, 3, 3, 3, 3]);
      expect(colors[2].argb, 0xff0a1403);
      expect(colors[0].argb, isNull);
      expect(colors[1].argb, isNull);
      expect(colors[3].argb, ChkPlayerColor.palette[3]);
      for (var i = 0; i < doc.sections.length; i++) {
        if (doc.sections[i].name == 'VER ') {
          expect(edited.sections[i].payload, [206, 0]);
        } else {
          expect(edited.sections[i], same(doc.sections[i]));
        }
      }
      final bytes = edited.sections.last.payload;
      expect(bytes.sublist(0, 3), [10, 20, 3]);
      expect(bytes.sublist(24, 28), [0, 1, 2, 3]);
    },
  );
  test(
    'CRGB edits preserve unknown modes and unused channel bytes elsewhere',
    () {
      var doc = ChkPlayerColors.edit(editingDocument(), {
        0: const ChkPlayerColor(2, 1, 2, 3),
      });
      final bytes = doc.sections.last.payload.toList()
        ..[25] = 99
        ..[3] = 77;
      doc = doc.replaceSection(
        doc.sections.length - 1,
        doc.sections.last.withPayload(bytes),
      );
      final edited = ChkPlayerColors.edit(doc, {
        0: const ChkPlayerColor(3, 1, 2, 7),
      });
      expect(edited.sections.last.payload[25], 99);
      expect(edited.sections.last.payload[3], 77);
      expect(ChkPlayerColors.preview(edited, 1), isNull);
      expect(ChkPlayerColors.preview(edited, 9), isNull);
      expect(edited.sections.last.payload[0], 1);
    },
  );
  test('CRGB malformed duplicate and invalid changes reject atomically', () {
    final doc = editingDocument();
    for (final malformed in [
      doc.appendSection(editingSection('CRGB', [0])),
      doc
          .appendSection(editingSection('CRGB', List.filled(32, 0)))
          .appendSection(editingSection('CRGB', List.filled(32, 0))),
    ]) {
      expect(
        () => ChkPlayerColors.edit(malformed, {
          0: const ChkPlayerColor(2, 1, 2, 3),
        }),
        throwsFormatException,
      );
      expect(ChkPlayerColors.preview(malformed, 0), isNull);
    }
    for (final color in [
      const ChkPlayerColor(4, 0, 0, 0),
      const ChkPlayerColor(2, -1, 0, 0),
      const ChkPlayerColor(3, 0, 0, 255),
    ]) {
      expect(
        () => ChkPlayerColors.edit(doc, {0: color}),
        throwsFormatException,
      );
    }
    expect(doc.sections.any((s) => s.name == 'CRGB'), isFalse);
  });
  test('trigger index searches text owners opcodes and typed references', () {
    final doc = editingDocument();
    final data = withRecords(doc, [
      triggerAction(doc, 9),
      triggerAction(doc, 10),
    ]);
    final search = ChkTriggerSearch(
      data,
      opcodeLabel: (_, id) => id == 9 ? '문자 표시' : '화면 이동',
    );
    expect(search.find('mission ALPHA'), [0]);
    expect(search.find('문자 표시'), [0]);
    expect(search.find('center view'), [1]);
    expect(search.find('Player 1'), [0, 1]);
    expect(search.find('', reference: 'location', id: 64), [1]);
    expect(search.find('', reference: 'string', id: 1), [0]);
    expect(search.find('', reference: 'location', id: 20), isEmpty);
  });
  test(
    'location replacement preview changes two arguments and preserves other records',
    () {
      final doc = editingDocument();
      final record = triggerAction(doc, 39).withSlotEnabled(true, 0, false);
      final data = withRecords(doc, [record, record]);
      final search = ChkTriggerSearch(data);
      final preview = search.replace(
        selected: {1},
        reference: 'location',
        from: 64,
        to: 2,
      );
      expect(preview.replacements, 2);
      expect(preview.changedRecords, {1});
      expect(preview.records[0], same(search.records[0]));
      final op = TriggerOpcodes.find(true, 39)!;
      for (final arg in op.arguments.where((a) => a.reference == 'location')) {
        expect(ChkTrigger.argument(preview.records[1].slot(true, 0), arg), 2);
      }
      expect(preview.records[1].slot(true, 0)[28], record.slot(true, 0)[28]);
      expect(search.records[1].bytes, record.bytes);
      expect(
        () => search.replace(
          selected: {0},
          reference: 'location',
          from: 64,
          to: 999,
        ),
        throwsFormatException,
      );
      expect(
        () => search.replace(
          selected: {2},
          reference: 'location',
          from: 64,
          to: 2,
        ),
        throwsRangeError,
      );
    },
  );
  test('unsupported extension and unknown slots remain read only', () {
    final doc = editingDocument();
    final record = triggerAction(doc, 10),
        bytes = record.bytes.toList()..[350] = 0x53;
    final unknown = ChkTrigger.create().bytes.toList()..[346] = 250;
    final search = ChkTriggerSearch(
      withRecords(doc, [ChkTrigger(bytes), ChkTrigger(unknown)]),
    );
    expect(search.find('opcode 250'), [1]);
    final preview = search.replace(
      selected: {0, 1},
      reference: 'location',
      from: 64,
      to: 2,
    );
    expect(preview.replacements, 0);
    expect(preview.skipped, 1);
    expect(preview.records[0].bytes, bytes);
    expect(preview.records[1].bytes, unknown);
  });
  test('supported reference kinds validate bounds and no-op', () {
    final doc = editingDocument();
    for (final kind in ChkTriggerSearch.replaceable) {
      final op = TriggerOpcodes.actions.firstWhere(
        (o) => o.arguments.any((a) => a.reference == kind),
      );
      final search = ChkTriggerSearch(
        withRecords(doc, [triggerAction(doc, op.id)]),
      );
      final hit = search.references.firstWhere(
        (h) => h.argument.reference == kind,
      );
      final to = kind == 'location'
          ? 2
          : kind == 'string' || kind == 'property'
          ? 2
          : 1;
      final preview = search.replace(
        selected: {0},
        reference: kind,
        from: hit.value,
        to: to,
      );
      expect(preview.replacements, greaterThan(0), reason: kind);
      expect(
        search
            .replace(
              selected: {0},
              reference: kind,
              from: hit.value,
              to: hit.value,
            )
            .replacements,
        0,
      );
    }
  });
  test(
    'briefing references use MBRF layouts and duplicate TRIG is refused',
    () {
      final doc = editingDocument();
      final search = ChkTriggerSearch(
        withRecords(doc, [
          triggerAction(doc, 3, briefing: true),
        ], briefing: true),
        briefing: true,
      );
      expect(search.find('mission'), [0]);
      final preview = search.replace(
        selected: {0},
        reference: 'string',
        from: 1,
        to: 2,
      );
      expect(preview.records.single.briefing, isTrue);
      expect(preview.replacements, 1);
      expect(
        () => ChkTriggerSearch(doc.appendSection(editingSection('TRIG', []))),
        throwsFormatException,
      );
    },
  );
  test(
    'ordinary defaults preserve fixed HP, disabled shields and unknown inheritance',
    () {
      final columns = syntheticDatColumns();
      columns['unit.hitpoints']![0] = 40 * 256 + 128;
      columns['unit.maxShield']![0] = 60;
      final dat = syntheticDatSource(columns).snapshot;
      expect(
        ChkUnitSettingField.hitpoints.display(
          ChkSettingsDefaults.unit(dat, 0, ChkUnitSettingField.hitpoints)!,
        ),
        '40.5',
      );
      expect(ChkSettingsDefaults.unit(dat, 0, ChkUnitSettingField.shields), 0);
      expect(
        ChkSettingsDefaults.unit(null, 0, ChkUnitSettingField.armor),
        isNull,
      );
      expect(
        ChkSettingsDefaults.expected(mode: 0, stored: 20, baseline: 40),
        20,
      );
      expect(
        ChkSettingsDefaults.expected(mode: 1, stored: 20, baseline: 40),
        40,
      );
      expect(
        ChkSettingsDefaults.expected(mode: 7, stored: 20, baseline: 40),
        isNull,
      );
      expect(
        ChkSettingsDefaults.expected(mode: 1, stored: 20, baseline: null),
        isNull,
      );
    },
  );
}
