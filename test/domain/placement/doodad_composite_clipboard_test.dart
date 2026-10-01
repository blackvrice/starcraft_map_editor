import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk_basic_editing.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_composite_clipboard.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import '../../fixtures/basic_editing_fixture.dart';

void main() {
  test(
    'verified disabled composite copy/cut/paste retains owner/state and restores underlying terrain',
    () {
      const e = ChkBasicEditing();
      var doc = basicDocument();
      final dd = ByteData(8)
        ..setUint16(0, 7, Endian.little)
        ..setUint16(2, 48, Endian.little)
        ..setUint16(4, 48, Endian.little)
        ..setUint8(6, 3)
        ..setUint8(7, 1);
      final sp = ByteData(10)
        ..setUint16(0, 100, Endian.little)
        ..setUint16(2, 48, Endian.little)
        ..setUint16(4, 48, Endian.little)
        ..setUint8(6, 3)
        ..setUint16(8, 0x8000, Endian.little);
      for (final (name, bytes) in [
        ('DD2 ', dd.buffer.asUint8List()),
        ('THG2', sp.buffer.asUint8List()),
      ]) {
        final old = e.section(doc, name)!;
        doc = doc.replaceSection(
          doc.sections.indexOf(old),
          old.withPayload(bytes),
        );
      }
      final m = e.section(doc, 'MTXM')!, tiles = m.payload;
      ByteData.sublistView(tiles).setUint16(66, 3200, Endian.little);
      doc = doc.replaceSection(doc.sections.indexOf(m), m.withPayload(tiles));
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
      final clip = DoodadCompositeClipboard.capture(
        doc,
        recipe: recipe,
        recordIndex: 0,
        overlayRecordIndex: 0,
      );
      expect(
        () => DoodadCompositeClipboard.capture(
          doc,
          recipe: recipe,
          recordIndex: 0,
        ),
        throwsStateError,
      );
      final pasted = clip.paste(doc, tileX: 20, tileY: 20),
          data = basicData(pasted, 'DD2 ');
      expect(data.lengthInBytes, 16);
      expect(data.getUint16(10, Endian.little), 656);
      expect(data.getUint8(14), 3);
      expect(data.getUint8(15), 1);
      expect(basicData(pasted, 'THG2').getUint16(18, Endian.little), 0x8000);
      expect(
        basicData(pasted, 'MTXM').getUint16((20 * 32 + 20) * 2, Endian.little),
        3200,
      );
      expect(e.section(pasted, 'TILE'), same(e.section(doc, 'TILE')));
      expect(() => clip.paste(doc, tileX: 2, tileY: 2), throwsStateError);
      expect(() => clip.paste(doc, tileX: 32, tileY: 31), throwsRangeError);
      final normalized = e.setDoodadEnabled(
        doc,
        recipe: recipe,
        recordIndex: 0,
        enabled: true,
        overlayRecordIndex: 0,
      );
      expect(basicData(normalized, 'DD2 ').getUint8(7), 0);
      final cut = DoodadCompositeClipboard.cut(
        doc,
        recipe: recipe,
        recordIndex: 0,
        overlayRecordIndex: 0,
      );
      expect(basicData(cut, 'MTXM').getUint16(66, Endian.little), 1);
      expect(basicData(cut, 'DD2 ').lengthInBytes, 0);
      expect(basicData(cut, 'THG2').lengthInBytes, 0);
      final restored = clip.paste(cut, tileX: 1, tileY: 1);
      expect(
        e.section(restored, 'DD2 ')!.payload,
        e.section(doc, 'DD2 ')!.payload,
      );
      expect(
        e.section(restored, 'THG2')!.payload,
        e.section(doc, 'THG2')!.payload,
      );
      expect(
        e.section(restored, 'MTXM')!.payload,
        e.section(doc, 'MTXM')!.payload,
      );
    },
  );
}
