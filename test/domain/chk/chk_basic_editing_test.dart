import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk_basic_editing.dart';
import '../../fixtures/basic_editing_fixture.dart';

void main() {
  const e = ChkBasicEditing();
  test(
    'fog edits one player, preserves unrelated bytes and rejects partial failure',
    () {
      final doc = basicDocument(), unknown = doc.sections.last;
      final edited = e.paintFog(
        doc,
        [(1, 2), (1, 2)],
        player: 3,
        hidden: false,
      );
      expect(e.fog(edited)[65], 247);
      expect(e.fog(doc)[65], 255);
      expect(edited.sections.last, same(unknown));
      expect(
        e.paintFog(edited, [(1, 2)], player: 3, hidden: false),
        same(edited),
      );
      expect(
        () => e.paintFog(doc, [(0, 0), (32, 0)], player: 0, hidden: false),
        throwsRangeError,
      );
      expect(e.fog(doc).every((v) => v == 255), isTrue);
      expect(
        () => e.paintFog(
          doc.appendSection(basicSection('MASK', [1])),
          [(0, 0)],
          player: 0,
          hidden: false,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'batch unit states distinguish inheritance, stored value and valid fields',
    () {
      final a = basicUnit(), b = basicUnit();
      ByteData.sublistView(a)
        ..setUint16(12, 0x8002, Endian.little)
        ..setUint16(26, 0x4002, Endian.little)
        ..setUint16(14, 0x8000, Endian.little);
      final doc = basicDocument(units: [a, b]);
      final edited = e.patchUnits(
        doc,
        {0, 1},
        states: {1: true, 2: null, 16: false},
        hitpoints: 25,
        resources: 12345,
      );
      final d = basicData(edited, 'UNIT');
      expect(d.getUint16(12, Endian.little), 0x8011);
      expect(d.getUint16(26, Endian.little), 0x4003);
      expect(d.getUint16(14, Endian.little), 0x8012);
      expect(d.getUint8(17), 25);
      expect(d.getUint32(56, Endian.little), 12345);
      expect(
        () => e.patchUnits(doc, {0, 2}, states: {1: true}),
        throwsRangeError,
      );
      expect(basicData(doc, 'UNIT').getUint16(12, Endian.little), 0x8002);
      expect(() => e.patchUnits(doc, {0}, energy: 101), throwsRangeError);
      expect(e.patchUnits(doc, {}), same(doc));
    },
  );
  test('location edits preserve unknown elevation bits and string IDs', () {
    final doc = basicDocument(), old = e.section(doc, 'MRGN')!;
    final bytes = old.payload;
    ByteData.sublistView(bytes)
      ..setUint16(18, 0x8040, Endian.little)
      ..setUint16(16, 7, Endian.little);
    final source = doc.replaceSection(
      doc.sections.indexOf(old),
      old.withPayload(bytes),
    );
    final d = basicData(e.setLocationElevation(source, 0, 9), 'MRGN');
    expect(d.getUint16(18, Endian.little), 0x8049);
    expect(d.getUint16(16, Endian.little), 7);
    expect(() => e.setLocationElevation(source, 255, 9), throwsRangeError);
  });
  test(
    'start positions use unit 214, unique class IDs and reject duplicate owners',
    () {
      final doc = basicDocument(units: [basicUnit(id: 1)]);
      final edited = e.setStartLocation(doc, player: 4, x: 50, y: 60),
          d = basicData(edited, 'UNIT');
      expect(d.getUint32(36, Endian.little), 2);
      expect(d.getUint16(44, Endian.little), 214);
      expect(d.getUint8(52), 4);
      expect(e.setStartLocation(edited, player: 4, x: 50, y: 60), same(edited));
      expect(
        () => e.setStartLocation(doc, player: 0, x: 1024, y: 1),
        throwsRangeError,
      );
      final duplicates = basicDocument(
        units: [basicUnit(type: 214), basicUnit(type: 214)],
      );
      expect(
        () => e.setStartLocation(duplicates, player: 0, x: 1, y: 1),
        throwsStateError,
      );
    },
  );
  test(
    'addon links accept either selection order and unlink the mutual peer atomically',
    () {
      final doc = basicDocument(
        units: [basicUnit(type: 120), basicUnit(type: 113)],
      );
      final linked = e.linkUnits(doc, 0, 1, addon: true),
          d = basicData(linked, 'UNIT');
      expect(d.getUint16(10, Endian.little), 0x400);
      expect(d.getUint32(32, Endian.little), d.getUint32(36, Endian.little));
      expect(d.getUint32(68, Endian.little), d.getUint32(0, Endian.little));
      expect(() => e.patchUnits(linked, {0}, owner: 1), throwsStateError);
      final unlinked = e.unlinkUnits(linked, {0}),
          u = basicData(unlinked, 'UNIT');
      expect(u.getUint32(32, Endian.little), 0);
      expect(u.getUint32(68, Endian.little), 0);
      expect(u.getUint16(46, Endian.little), 0);
      expect(e.unlinkUnits(unlinked, {0, 1}), same(unlinked));
    },
  );
  test(
    'nydus and ambiguous relations reject unsupported or broken records without mutation',
    () {
      final doc = basicDocument(
        units: [basicUnit(type: 134, id: 1), basicUnit(type: 134, id: 2)],
      );
      final linked = e.linkUnits(doc, 0, 1, addon: false);
      expect(basicData(linked, 'UNIT').getUint16(10, Endian.little), 0x200);
      final old = e.section(linked, 'UNIT')!, bytes = old.payload;
      ByteData.sublistView(bytes).setUint32(68, 9, Endian.little);
      final broken = linked.replaceSection(
        linked.sections.indexOf(old),
        old.withPayload(bytes),
      );
      expect(() => e.unlinkUnits(broken, {0}), throwsStateError);
      expect(() => e.linkUnits(doc, 0, 1, addon: true), throwsStateError);
      final sameIds = basicDocument(
        units: [basicUnit(type: 134, id: 1), basicUnit(type: 134, id: 1)],
      );
      expect(() => e.linkUnits(sameIds, 0, 1, addon: false), throwsStateError);
    },
  );
}
