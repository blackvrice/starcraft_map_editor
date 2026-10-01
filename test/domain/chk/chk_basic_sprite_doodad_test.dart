import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk_basic_editing.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import '../../fixtures/basic_editing_fixture.dart';

void main() {
  const e = ChkBasicEditing();
  test(
    'sprite-unit disabled preserves every unknown flag and pure sprite rejection is atomic',
    () {
      final doc = basicDocument(), s = e.section(doc, 'THG2')!;
      final bytes = Uint8List(20);
      ByteData.sublistView(bytes)
        ..setUint16(8, 0x2043, Endian.little)
        ..setUint16(18, 0x1000, Endian.little);
      final source = doc.replaceSection(
        doc.sections.indexOf(s),
        s.withPayload(bytes),
      );
      final d = basicData(
        e.patchSprites(source, {0}, owner: 5, disabled: true),
        'THG2',
      );
      expect(d.getUint16(8, Endian.little), 0xa043);
      expect(d.getUint8(6), 5);
      expect(
        () => e.patchSprites(source, {0, 1}, disabled: true),
        throwsStateError,
      );
      expect(basicData(source, 'THG2').getUint16(8, Endian.little), 0x2043);
    },
  );
  test(
    'verified Doodad disable and enable synchronize DD2 and explicit sprite-unit overlay',
    () {
      var doc = basicDocument();
      final dd = ByteData(8)
        ..setUint16(0, 7, Endian.little)
        ..setUint16(2, 48, Endian.little)
        ..setUint16(4, 48, Endian.little);
      final sprite = ByteData(10)
        ..setUint16(0, 100, Endian.little)
        ..setUint16(2, 48, Endian.little)
        ..setUint16(4, 48, Endian.little);
      for (final (name, bytes) in [
        ('DD2 ', dd.buffer.asUint8List()),
        ('THG2', sprite.buffer.asUint8List()),
      ]) {
        final s = e.section(doc, name)!;
        doc = doc.replaceSection(doc.sections.indexOf(s), s.withPayload(bytes));
      }
      final m = e.section(doc, 'MTXM')!, tile = m.payload;
      ByteData.sublistView(tile).setUint16(33 * 2, 3200, Endian.little);
      doc = doc.replaceSection(doc.sections.indexOf(m), m.withPayload(tile));
      final recipe = DoodadPlacementRecipe(
        tileset: StarCraftTilesetAssetSet.badlands,
        startTileGroup: 200,
        doodadType: 7,
        width: 1,
        height: 1,
        centerOffsetX: 16,
        centerOffsetY: 16,
        footprint: [
          DoodadFootprintCell(
            x: 0,
            y: 0,
            rawTileValue: 3200,
            requiredTileGroup: 0,
          ),
        ],
        overlay: DoodadOverlayRecipe(
          semantic: DoodadOverlaySemantic.spriteUnit,
          id: 100,
        ),
      );
      expect(
        () => e.setDoodadEnabled(
          doc,
          recipe: recipe,
          recordIndex: 0,
          enabled: false,
        ),
        throwsStateError,
      );
      final disabled = e.setDoodadEnabled(
        doc,
        recipe: recipe,
        recordIndex: 0,
        enabled: false,
        overlayRecordIndex: 0,
      );
      expect(basicData(disabled, 'DD2 ').getUint8(7), 1);
      expect(basicData(disabled, 'THG2').getUint16(8, Endian.little), 0x8000);
      expect(e.section(disabled, 'MTXM'), same(e.section(doc, 'MTXM')));
      final enabled = e.setDoodadEnabled(
        disabled,
        recipe: recipe,
        recordIndex: 0,
        enabled: true,
        overlayRecordIndex: 0,
      );
      expect(basicData(enabled, 'DD2 ').getUint8(7), 0);
      expect(basicData(enabled, 'THG2').getUint16(8, Endian.little), 0);
      expect(() => e.patchSprites(doc, {0}, disabled: true), throwsStateError);
      final broken = e.section(doc, 'TILE')!;
      final bad = doc.replaceSection(
        doc.sections.indexOf(broken),
        broken.withPayload(tile),
      );
      expect(
        () => e.setDoodadEnabled(
          bad,
          recipe: recipe,
          recordIndex: 0,
          enabled: false,
          overlayRecordIndex: 0,
        ),
        throwsStateError,
      );
    },
  );
}
