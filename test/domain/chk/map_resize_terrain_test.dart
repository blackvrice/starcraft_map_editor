import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/map_resize.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_doodad_overlay.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/domain/terrain/map_resize_terrain.dart';
import '../../fixtures/isom_ramp_fixture.dart';
import '../../fixtures/solid_isom_fixture.dart';

RawChkSection section(RawChkDocument d, String name) =>
    d.sections.singleWhere((s) => s.name == name);
RawChkDocument put(RawChkDocument d, String name, List<int> b) {
  final i = d.sections.indexWhere((s) => s.name == name);
  return d.replaceSection(i, d.sections[i].withPayload(b));
}

void main() {
  final c = const TransitionIsomCatalogBuilder().build(solidSnapshot());
  final recipe = IsomRampGateway().recipe;
  final data = MapResizeTerrainData(
    catalog: c.catalog,
    brush: c.brush!,
    solids: c.shapes,
    recipes: [recipe],
  );
  RawChkDocument base({int width = 64, int height = 64}) {
    var d = const IsomTerrainFill()
        .preview(
          const NewMapFactory().create(
            NewMapOptions(width: width, height: height, rawTileValue: 0),
          ),
          c.catalog,
          solidValue: 16,
          seed: 0,
        )
        .result;
    final units = section(d, 'UNIT').payload;
    ByteData.sublistView(units)
      ..setUint16(4, 512, Endian.little)
      ..setUint16(6, 512, Endian.little);
    d = put(d, 'UNIT', units);
    final isom = section(d, 'ISOM').payload;
    for (var i = 0; i < isom.length; i += 2) {
      isom[i] |= 1;
      isom[i + 1] |= 128;
    }
    return put(d, 'ISOM', isom).appendSection(
      RawChkSection(
        nameBytes: '????'.codeUnits,
        declaredLength: 3,
        payload: [0, 255, 3],
        sourceOffset: 0,
      ),
    );
  }

  test(
    'nine anchors preserve ISOM overlap flags, tile members, fog and unknown order',
    () {
      final source = base(), before = const RawChkEncoder().encode(source);
      for (final anchor in MapResizeAnchor.values) {
        final p = const MapResizeEditor().preview(
          source,
          MapResizeOptions(width: 96, height: 128, anchor: anchor),
          terrainData: data,
        );
        expect(p.blockers, isEmpty, reason: anchor.name);
        final result = p.apply(acceptCropping: false);
        expect(
          result.sections.map((s) => s.name),
          source.sections.map((s) => s.name),
        );
        expect(section(result, '????'), same(section(source, '????')));
        final old = section(source, 'ISOM').payload,
            newBytes = section(result, 'ISOM').payload;
        for (var y = 0; y <= 64; y++) {
          final at = ((y + p.dy) * 49 + p.dx ~/ 2) * 8;
          expect(
            newBytes.sublist(at, at + 33 * 8),
            old.sublist(y * 33 * 8, (y + 1) * 33 * 8),
          );
        }
        final oldTile = section(source, 'TILE').payload,
            tiles = section(result, 'TILE').payload;
        for (var y = 0; y < 64; y++) {
          expect(
            tiles.sublist(
              ((y + p.dy) * 96 + p.dx) * 2,
              ((y + p.dy) * 96 + p.dx + 64) * 2,
            ),
            oldTile.sublist(y * 128, (y + 1) * 128),
          );
        }
        expect(
          section(result, 'MASK').payload.last,
          anchor == MapResizeAnchor.bottomRight
              ? section(source, 'MASK').payload.last
              : 255,
        );
      }
      expect(const RawChkEncoder().encode(source), before);
    },
  );
  test(
    'resize active/disabled doodads and all sprites together without guessing ownership',
    () {
      var source = IsomDoodadOverlay.placeRamp(
        base(),
        recipe,
        x: 8,
        y: 10,
        recipes: [recipe],
      );
      final sprite = ByteData(10)
        ..setUint16(0, 130, Endian.little)
        ..setUint16(2, 288, Endian.little)
        ..setUint16(4, 336, Endian.little)
        ..setUint16(8, 0x9000, Endian.little);
      source = put(source, 'THG2', sprite.buffer.asUint8List());
      for (final disabled in [false, true]) {
        final dd = section(source, 'DD2 ').payload;
        dd[7] = disabled ? 1 : 0;
        final input = put(source, 'DD2 ', dd);
        final p = const MapResizeEditor().preview(
          input,
          MapResizeOptions(
            width: 96,
            height: 96,
            anchor: MapResizeAnchor.center,
          ),
          terrainData: data,
        );
        expect(p.blockers, isEmpty);
        expect(p.movedDoodads, 1);
        expect(p.outsideDoodads, 0);
        expect(p.movedSprites, 1);
        final result = p.apply(acceptCropping: false);
        final moved = ByteData.sublistView(section(result, 'DD2 ').payload);
        expect(moved.getUint16(2, Endian.little), 288 + 512);
        expect(section(result, 'DD2 ').payload[7], disabled ? 1 : 0);
        final sp = ByteData.sublistView(section(result, 'THG2').payload);
        expect(sp.getUint16(2, Endian.little), 800);
        expect(sp.getUint16(8, Endian.little), 0x9000);
        expect(
          const ChkTerrainViewDecoder()
              .decode(result)
              .tileMaps
              .single
              .rawTileValues[26 * 96 + 24],
          1600,
        );
        IsomDoodadOverlay.read(result, [recipe], allowDisabled: true);
        // Cropping the new margin restores the original byte representation.
        final crop = const MapResizeEditor().preview(
          result,
          MapResizeOptions(
            width: 64,
            height: 64,
            anchor: MapResizeAnchor.center,
          ),
          terrainData: data,
        );
        expect(crop.blockers, isEmpty);
        expect(
          const RawChkEncoder().encode(crop.apply(acceptCropping: true)),
          const RawChkEncoder().encode(input),
        );
      }
    },
  );
  test(
    'partial footprint crop blocks even when the doodad center remains inside',
    () {
      final source = IsomDoodadOverlay.placeRamp(
        base(),
        recipe,
        x: 31,
        y: 8,
        recipes: [recipe],
      );
      final p = const MapResizeEditor().preview(
        source,
        MapResizeOptions(width: 32, height: 32),
        terrainData: data,
      );
      expect(p.canApply, isFalse);
      expect(p.outsideDoodads, 1);
      expect(p.result, isNull);
      expect(() => p.apply(acceptCropping: true), throwsStateError);
    },
  );
  test(
    'raw TILE doodads also translate; missing/ambiguous data and raw overrides block',
    () {
      final filled = IsomDoodadOverlay.placeRamp(
        base(),
        recipe,
        x: 8,
        y: 8,
        recipes: [recipe],
      );
      final raw = RawChkDocument(
        sections: filled.sections.where((s) => s.name != 'ISOM').toList(),
        sourceLength: filled.sourceLength,
      );
      final p = const MapResizeEditor().preview(
        raw,
        MapResizeOptions(width: 96, height: 96),
        terrainData: data,
      );
      expect(p.blockers, isEmpty);
      expect(section(p.result!, 'DD2 ').payload, section(raw, 'DD2 ').payload);
      final ambiguous = MapResizeTerrainData(
        catalog: c.catalog,
        brush: c.brush!,
        solids: c.shapes,
        recipes: [recipe, recipe],
      );
      expect(
        const MapResizeEditor()
            .preview(
              filled,
              MapResizeOptions(width: 96, height: 96),
              terrainData: ambiguous,
            )
            .canApply,
        isFalse,
      );
      final tiles = section(filled, 'MTXM').payload;
      tiles[0] = 255;
      expect(
        const MapResizeEditor()
            .preview(
              put(filled, 'MTXM', tiles),
              MapResizeOptions(width: 96, height: 96),
              terrainData: data,
            )
            .canApply,
        isFalse,
      );
      expect(
        const MapResizeEditor()
            .preview(filled, MapResizeOptions(width: 96, height: 96))
            .canApply,
        isFalse,
      );
    },
  );
  test('256 square resize and damaged ISOM rejection preserve the source', () {
    final source = base(), original = const RawChkEncoder().encode(source);
    final p = const MapResizeEditor().preview(
      source,
      MapResizeOptions(width: 256, height: 256, anchor: MapResizeAnchor.center),
      terrainData: data,
    );
    expect(p.blockers, isEmpty);
    expect(section(p.result!, 'ISOM').payload.length, 129 * 257 * 8);
    final bad = section(source, 'ISOM').payload;
    bad[0] = 0;
    bad[1] = 0;
    final rejected = const MapResizeEditor().preview(
      put(source, 'ISOM', bad),
      MapResizeOptions(width: 96, height: 96),
      terrainData: data,
    );
    expect(rejected.canApply, isFalse);
    expect(rejected.result, isNull);
    expect(const RawChkEncoder().encode(source), original);
  });
}
