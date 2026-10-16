import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_paint.dart';
import '../../fixtures/basic_editing_fixture.dart';
import '../../fixtures/mixed_clipboard_fixture.dart';
import '../../fixtures/solid_isom_fixture.dart';

void main() {
  final data = MixedClipboardData(recipes: [mixedRecipe]);
  final region = ClipboardRegion(0, 0, 7, 5);
  const kinds = {'UNIT', 'THG2', 'MRGN', 'DD2 '};
  test(
    'location names stay bound to exact raw bytes, not just a reused string ID',
    () {
      var doc = mixedDocument();
      final loc = basicData(doc, 'MRGN')..setUint16(16, 1, Endian.little);
      doc = mixedPut(doc, 'MRGN', loc.buffer.asUint8List());
      final clip = ChkMixedClipboard.capture(
        doc,
        region: region,
        profile: MixedClipboardProfile.raw,
        kinds: kinds,
        overlays: {0: 2, 1: 1},
        data: data,
      );
      final table = const ChkStringViewDecoder()
          .decode(doc)
          .legacyTables
          .single;
      final changed = table.rawSection.payload;
      changed[table.entryForId(1)!.rawOffset] ^= 1;
      final target = mixedPut(doc, table.rawSection.name, changed);
      expect(() => clip.paste(target, x: 16, y: 16), throwsStateError);
      expect(() => clip.paste(doc, x: 16, y: 16), returnsNormally);
    },
  );
  test(
    'raw profile supports absent TILE and preserves duplicate unknown sections',
    () {
      final base = basicDocument();
      final doc = RawChkDocument(
        sections: base.sections.where((s) => s.name != 'TILE').toList(),
        sourceLength: base.sourceLength,
      ).appendSection(basicSection('ZZZZ', [33]));
      final clip = ChkMixedClipboard.capture(
        doc,
        region: ClipboardRegion(0, 0, 0, 0),
        profile: MixedClipboardProfile.raw,
        kinds: {},
        overlays: {},
        data: MixedClipboardData(recipes: []),
      );
      final pasted = clip.paste(doc, x: 8, y: 8);
      expect(pasted.sections.where((s) => s.name == 'TILE'), isEmpty);
      expect(
        pasted.sections.where((s) => s.name == 'ZZZZ').map((s) => s.payload),
        [
          [255, 0, 17],
          [33],
        ],
      );
      final cut = clip.cut(rawReplacement: 1);
      expect(cut.sections.where((s) => s.name == 'TILE'), isEmpty);
    },
  );
  test(
    'Anywhere and starts are skipped; duplicate known sections and protection are refused',
    () {
      final doc = mixedDocument();
      final clip = ChkMixedClipboard.capture(
        doc,
        region: ClipboardRegion(0, 0, 31, 31),
        profile: MixedClipboardProfile.raw,
        kinds: kinds,
        overlays: {0: 2, 1: 1},
        data: data,
      );
      expect(clip.skippedReserved, 2);
      expect(
        () => ChkMixedClipboard.capture(
          doc.appendSection(
            basicSection('MTXM', basicData(doc, 'MTXM').buffer.asUint8List()),
          ),
          region: region,
          profile: MixedClipboardProfile.raw,
          kinds: kinds,
          overlays: {0: 2, 1: 1},
          data: data,
        ),
        throwsStateError,
      );
      final protected = doc.appendSection(
        RawChkSection.euddraftProtectionMarker(
          declaredLength: 0xffffffff,
          sourceOffset: 0,
        ),
      );
      expect(
        () => ChkMixedClipboard.capture(
          protected,
          region: region,
          profile: MixedClipboardProfile.raw,
          kinds: kinds,
          overlays: {0: 2, 1: 1},
          data: data,
        ),
        throwsStateError,
      );
    },
  );
  ChkMixedClipboard capture(
    RawChkDocument d, {
    ClipboardRegion? area,
    Map<int, int> overlays = const {0: 2, 1: 1},
    Set<String> include = kinds,
  }) => ChkMixedClipboard.capture(
    d,
    region: area ?? region,
    profile: MixedClipboardProfile.raw,
    kinds: include,
    overlays: overlays,
    data: data,
  );
  test(
    'multiple adjacent doodads, paired units, sprites and inverted locations retain relative bytes/order',
    () {
      final source = mixedDocument(),
          before = const RawChkEncoder().encode(mixedDocument());
      final clip = capture(source);
      expect(clip.objectCount, 8); // 2 DD2 + 2 UNIT + 3 THG2 + 1 MRGN.
      expect(clip.skippedReserved, 1);
      final pasted = clip.paste(source, x: 16, y: 16);
      expect(basicData(pasted, 'DD2 ').lengthInBytes, 32);
      expect(basicData(pasted, 'DD2 ').getUint16(18, Endian.little), 96 + 512);
      expect(basicData(pasted, 'DD2 ').getUint8(31), 1);
      final sp = basicData(pasted, 'THG2');
      expect(sp.lengthInBytes, 60);
      expect(sp.getUint16(32, Endian.little), 120 + 512);
      expect(sp.getUint16(48, Endian.little), 0x8000);
      final units = basicData(pasted, 'UNIT');
      expect(units.lengthInBytes, 180);
      final a = units.getUint32(108, Endian.little),
          b = units.getUint32(144, Endian.little);
      expect(a, isNot(anyOf(11, 12, 13)));
      expect(b, isNot(a));
      expect(units.getUint32(140, Endian.little), b);
      expect(units.getUint32(176, Endian.little), a);
      final loc = basicData(pasted, 'MRGN');
      expect(loc.getUint32(20, Endian.little), 160 + 512);
      expect(loc.getUint32(28, Endian.little), 96 + 512);
      expect(loc.getUint16(38, Endian.little), 19);
      expect(
        basicData(pasted, 'MTXM').getUint16((18 * 32 + 18) * 2, Endian.little),
        3200,
      );
      expect(pasted.sections.last, same(source.sections.last));
      expect(const RawChkEncoder().encode(source), before);
      final cut = clip.cut(rawReplacement: 1);
      expect(basicData(cut, 'DD2 ').lengthInBytes, 0);
      expect(basicData(cut, 'THG2').lengthInBytes, 0);
      expect(basicData(cut, 'UNIT').lengthInBytes, 36);
      expect(basicData(cut, 'UNIT').getUint16(8, Endian.little), 214);
      expect(basicData(cut, 'MRGN').getUint32(0, Endian.little), 0);
      expect(
        basicData(cut, 'MTXM').getUint16((2 * 32 + 2) * 2, Endian.little),
        1,
      );
      expect(
        basicData(cut, 'TILE').getUint16((2 * 32 + 2) * 2, Endian.little),
        1,
      );
      expect(
        basicData(clip.paste(cut, x: 0, y: 0), 'DD2 ').buffer.asUint8List(),
        basicData(source, 'DD2 ').buffer.asUint8List(),
      );
    },
  );
  test(
    'read-only rejection of partial footprints, missing/ambiguous overlay and excluded doodads',
    () {
      final doc = mixedDocument(),
          bytes = const RawChkEncoder().encode(mixedDocument());
      expect(
        () => capture(doc, area: ClipboardRegion(3, 0, 7, 5)),
        throwsStateError,
      );
      expect(() => capture(doc, overlays: {}), throwsStateError);
      expect(() => capture(doc, overlays: {0: 1, 1: 2}), throwsStateError);
      expect(
        () => capture(doc, include: {'UNIT', 'THG2', 'MRGN'}),
        throwsStateError,
      );
      final sp = basicData(doc, 'THG2').buffer.asUint8List();
      expect(
        () => capture(mixedPut(doc, 'THG2', [...sp, ...sp.sublist(20, 30)])),
        throwsStateError,
      );
      final m = basicData(doc, 'MTXM')
        ..setUint16((2 * 32 + 2) * 2, 0, Endian.little);
      expect(
        () => capture(mixedPut(doc, 'MTXM', m.buffer.asUint8List())),
        throwsStateError,
      );
      expect(const RawChkEncoder().encode(doc), bytes);
    },
  );
  test(
    'partial locations and broken incoming/outgoing UNIT references reject atomically',
    () {
      final doc = mixedDocument();
      final loc = basicData(doc, 'MRGN')..setUint32(8, 300, Endian.little);
      expect(
        () => capture(mixedPut(doc, 'MRGN', loc.buffer.asUint8List())),
        throwsStateError,
      );
      final unit = basicData(doc, 'UNIT')..setUint16(40, 300, Endian.little);
      expect(
        () => capture(mixedPut(doc, 'UNIT', unit.buffer.asUint8List())),
        throwsStateError,
      );
      final incoming = basicUnit(id: 99, x: 800, y: 800);
      ByteData.sublistView(incoming)
        ..setUint16(10, 0x200, Endian.little)
        ..setUint32(32, 11, Endian.little);
      expect(
        () => capture(
          mixedPut(doc, 'UNIT', [
            ...basicData(doc, 'UNIT').buffer.asUint8List(),
            ...incoming,
          ]),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'target footprint, map bounds, missing location capacity and coincident overlays reject',
    () {
      final doc = mixedDocument(), clip = capture(doc);
      expect(() => clip.paste(doc, x: 0, y: 0), throwsStateError);
      expect(() => clip.paste(doc, x: 30, y: 30), throwsStateError);
      final sp = ByteData(10)
        ..setUint16(0, 130, Endian.little)
        ..setUint16(2, 608, Endian.little)
        ..setUint16(4, 592, Endian.little)
        ..setUint16(8, 0x1000, Endian.little);
      expect(
        () => clip.paste(
          mixedPut(doc, 'THG2', [
            ...basicData(doc, 'THG2').buffer.asUint8List(),
            ...sp.buffer.asUint8List(),
          ]),
          x: 16,
          y: 16,
        ),
        throwsStateError,
      );
      final loc = basicData(doc, 'MRGN');
      for (var i = 0; i < loc.lengthInBytes; i += 20) {
        loc.setUint32(i, 1, Endian.little);
      }
      expect(
        () => clip.paste(
          mixedPut(doc, 'MRGN', loc.buffer.asUint8List()),
          x: 16,
          y: 16,
        ),
        throwsStateError,
      );
      expect(() => clip.cut(rawReplacement: 65535), throwsStateError);
    },
  );
  test(
    'confirmed doodad overlays follow even when standalone Sprite copying is disabled',
    () {
      final clip = capture(mixedDocument(), include: {'DD2 '});
      expect(clip.selected['THG2'], {1, 2});
      expect(clip.selected.containsKey('UNIT'), isFalse);
    },
  );
  test(
    'raw MTXM/TILE differences are copied independently and no TILE is fabricated',
    () {
      var doc = basicDocument();
      final m = basicData(doc, 'MTXM')..setUint16(0, 9, Endian.little);
      doc = mixedPut(doc, 'MTXM', m.buffer.asUint8List());
      final clip = ChkMixedClipboard.capture(
        doc,
        region: ClipboardRegion(0, 0, 0, 0),
        profile: MixedClipboardProfile.raw,
        kinds: {},
        overlays: {},
        data: MixedClipboardData(recipes: []),
      );
      final result = clip.paste(doc, x: 10, y: 10);
      expect(basicData(result, 'MTXM').getUint16(660, Endian.little), 9);
      expect(basicData(result, 'TILE').getUint16(660, Endian.little), 1);
    },
  );
  test(
    'ISOM copies verified shapes with multiple doodads; wrong phase/unsupported boundaries are rejected',
    () {
      final c = const TransitionIsomCatalogBuilder().build(solidSnapshot());
      final base = const IsomTerrainFill()
          .preview(basicDocument(), c.catalog, solidValue: 16, seed: 0)
          .result;
      final doc = mixedDocument(base: base);
      final clip = ChkMixedClipboard.capture(
        doc,
        region: ClipboardRegion(0, 0, 7, 5),
        profile: MixedClipboardProfile.isom,
        kinds: kinds,
        overlays: {0: 2, 1: 1},
        data: MixedClipboardData(
          recipes: [mixedRecipe],
          catalog: c.catalog,
          brush: c.brush,
        ),
      );
      final result = clip.paste(doc, x: 16, y: 16);
      expect(basicData(result, 'DD2 ').lengthInBytes, 32);
      expect(
        basicData(result, 'ISOM').buffer.asUint8List(),
        basicData(doc, 'ISOM').buffer.asUint8List(),
      );
      expect(() => clip.paste(doc, x: 14, y: 16), throwsStateError);
      expect(() => clip.cut(fillShape: 999), throwsStateError);
      final cut = clip.cut(fillShape: 1);
      expect(basicData(cut, 'DD2 ').lengthInBytes, 0);
      expect(IsomTerrainPaint.readDiamonds(cut, c.brush!).values.toSet(), {1});
      expect(
        () => ChkMixedClipboard.capture(
          doc,
          region: ClipboardRegion(1, 0, 8, 5),
          profile: MixedClipboardProfile.isom,
          kinds: kinds,
          overlays: {0: 2, 1: 1},
          data: clip.data,
        ),
        throwsStateError,
      );
    },
  );
}
