import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/terrain/user_terrain_brush.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_paint.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import '../../fixtures/basic_editing_fixture.dart';
import '../../fixtures/mixed_clipboard_fixture.dart';
import '../../fixtures/solid_isom_fixture.dart';
import '../../fixtures/user_terrain_brush_fixture.dart';

void main() {
  test(
    'raw metadata roundtrip preserves unrelated bytes and no-op identity',
    () {
      var doc = basicDocument().appendSection(basicSection('ZZZZ', [90]));
      final grid = basicData(doc, 'MTXM');
      grid.setUint16(0, 1023, Endian.little);
      doc = mixedPut(doc, 'MTXM', grid.buffer.asUint8List());
      final bytes = const RawChkEncoder().encode(doc);
      final brush = UserTerrainBrush.decode(
        UserTerrainBrush.capture(
          doc,
          name: ' Raw ',
          region: ClipboardRegion(0, 0, 1, 1),
          profile: TerrainBrushProfile.raw,
        ).encode(),
      );
      expect(brush.name, 'Raw');
      expect(() => brush.raw[0] = 0, throwsUnsupportedError);
      expect(brush.preview(doc, x: 0, y: 0), same(doc));
      final pasted = brush.preview(doc, x: 8, y: 8);
      expect(
        basicData(pasted, 'MTXM').getUint16((8 * 32 + 8) * 2, Endian.little),
        1023,
      );
      for (var i = 0; i < doc.sections.length; i++) {
        if (doc.sections[i].name != 'MTXM') {
          expect(pasted.sections[i], same(doc.sections[i]));
        }
      }
      expect(const RawChkEncoder().encode(doc), bytes);
      expect(
        () => brush.preview(doc, x: 0, y: 0, mirrorX: true),
        throwsStateError,
      );
      expect(() => brush.preview(doc, x: 31, y: 31), throwsStateError);
      expect(
        () => brush.preview(mixedPut(doc, 'ERA ', [1, 0]), x: 0, y: 0),
        throwsStateError,
      );
    },
  );
  test('strict version, dimensions, values, bounds and size validation', () {
    final base = jsonDecode(rawUserBrush().encode()) as Map<String, dynamic>;
    for (final patch in <Map<String, Object?>>[
      {'version': 2},
      {'version': 1.0},
      {'width': 257},
      {'height': 0},
      {
        'raw': [1],
      },
      {
        'raw': [0, 0, 0, 65536],
      },
      {
        'raw': [0, 0, 0, 1.5],
      },
      {'profile': 'future'},
      {'tileset': 8},
      {'name': '\u0000'},
      {'revision': 'future'},
      {'extra': true},
      {
        'shapes': [
          [1, 1, 1],
        ],
      },
    ]) {
      expect(
        () => UserTerrainBrush.decode(jsonEncode({...base, ...patch})),
        throwsFormatException,
        reason: '$patch',
      );
    }
    expect(
      () => UserTerrainBrush.decode(' ' * (UserTerrainBrush.maxBytes + 1)),
      throwsFormatException,
    );
  });
  test(
    'ISOM stores complete semantic diamonds and validates mirrors with solver',
    () {
      final data = const TransitionIsomCatalogBuilder().build(solidSnapshot());
      final doc = const IsomTerrainFill()
          .preview(basicDocument(), data.catalog, solidValue: 16, seed: 0)
          .result;
      final captured = UserTerrainBrush.capture(
        doc,
        name: 'Grass',
        region: ClipboardRegion(4, 4, 11, 9),
        profile: TerrainBrushProfile.isom,
        catalog: data.catalog,
        brush: data.brush,
      );
      final brush = UserTerrainBrush.decode(captured.encode());
      expect(brush.shapes, captured.shapes);
      expect(brush.raw, isEmpty);
      final original = const RawChkEncoder().encode(doc);
      for (final (mx, my) in [
        (false, false),
        (true, false),
        (false, true),
        (true, true),
      ]) {
        final result = brush.preview(
          doc,
          x: 16,
          y: 16,
          catalog: data.catalog,
          brush: data.brush,
          solidShapes: data.shapes.values.toSet(),
          mirrorX: mx,
          mirrorY: my,
        );
        expect(
          IsomTerrainPaint.readDiamonds(result, data.brush!).values.toSet(),
          {1},
        );
      }
      expect(const RawChkEncoder().encode(doc), original);
      final otherVariants = const IsomTerrainFill()
          .preview(basicDocument(), data.catalog, solidValue: 16, seed: 97)
          .result;
      expect(
        brush.preview(
          otherVariants,
          x: 8,
          y: 8,
          catalog: data.catalog,
          brush: data.brush,
        ),
        same(otherVariants),
      );
      expect(
        () => brush.preview(
          doc,
          x: 2,
          y: 2,
          catalog: data.catalog,
          brush: data.brush,
        ),
        throwsStateError,
      );
      expect(() => brush.preview(doc, x: 8, y: 8), throwsStateError);
      expect(
        () => brush.preview(
          doc,
          x: 8,
          y: 8,
          catalog: data.catalog,
          brush: data.brush,
          mirrorX: true,
        ),
        throwsStateError,
      );
      final encoded = jsonDecode(brush.encode()) as Map<String, dynamic>;
      for (final patch in <Map<String, Object?>>[
        {'shapes': []},
        {
          'shapes': [
            [1, 1, 1],
            [1, 1, 1],
          ],
        },
        {
          'shapes': [
            [0, 0, 1],
          ],
        },
        {
          'shapes': [
            [1, 2, 1],
          ],
        },
        {'width': 7},
      ]) {
        expect(
          () => UserTerrainBrush.decode(jsonEncode({...encoded, ...patch})),
          throwsFormatException,
        );
      }
      final stale = UserTerrainBrush.decode(
        jsonEncode({...encoded, 'revision': 'old'}),
      );
      expect(
        () => stale.preview(
          doc,
          x: 8,
          y: 8,
          catalog: data.catalog,
          brush: data.brush,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'DD2, duplicate known grids and raw/ISOM conversion are never guessed',
    () {
      final raw = rawUserBrush();
      expect(
        () => raw.preview(mixedDocument(), x: 16, y: 16),
        throwsStateError,
      );
      expect(
        () => UserTerrainBrush.capture(
          mixedDocument(),
          name: 'DD',
          region: ClipboardRegion(0, 0, 7, 5),
          profile: TerrainBrushProfile.raw,
        ),
        throwsStateError,
      );
      final doc = basicDocument();
      expect(
        () => raw.preview(
          doc.appendSection(
            basicSection('MTXM', basicData(doc, 'MTXM').buffer.asUint8List()),
          ),
          x: 0,
          y: 0,
        ),
        throwsStateError,
      );
      expect(
        () => UserTerrainBrush.capture(
          doc,
          name: 'ISOM',
          region: ClipboardRegion(0, 0, 7, 5),
          profile: TerrainBrushProfile.isom,
        ),
        throwsStateError,
      );
    },
  );
}
