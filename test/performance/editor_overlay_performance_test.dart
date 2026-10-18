import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/preplaced_unit_power_layout.dart';
import 'package:starcraft_map_editor/domain/placement/unit_power_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_range_projection.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/editor_overlay_fixture.dart';
import '../fixtures/eud_dat_fixture.dart';

void main() {
  test(
    '256x256 field and selected ranges stay within bounded debug paint work',
    () {
      final doc = basicDocument(
        units: [
          for (var i = 0; i < 256; i++)
            basicUnit(type: 156, x: 512 + i % 16 * 448, y: 512 + i ~/ 16 * 448),
        ],
      );
      final records = doc.sections.singleWhere((s) => s.name == 'UNIT').payload;
      for (var i = 0; i < 256; i++) {
        ByteData.sublistView(records).setUint16(i * 36 + 14, 1, Endian.little);
      }
      final updated = doc.replaceSection(
        doc.sections.indexWhere((s) => s.name == 'UNIT'),
        basicSection('UNIT', records),
      );
      final units = const ChkObjectViewDecoder()
          .decode(updated)
          .unitSections
          .single
          .units;
      final field = UnitPowerCatalog({156: overlayCapability(156)}).project(
        owner: 0,
        mapWidthTiles: 256,
        mapHeightTiles: 256,
        existing: PreplacedUnitPowerLayout.project(units),
      );
      expect(field.failure, isNull);
      expect(field.providers.length, 256);
      final columns = syntheticDatColumns();
      columns['unit.sightRange']![156] = 7;
      columns['unit.groundWeapon']![156] = 0;
      columns['unit.airWeapon']![156] = 1;
      columns['weapon.maxRange']![0] = 128;
      columns['weapon.maxRange']![1] = 192;
      final ranges = UnitRangeProjection.fromDat(
        dat: syntheticDatSource(columns).snapshot,
        selected: units.take(64),
        mapWidth: 256,
        mapHeight: 256,
      );
      expect(ranges.rings.length, 192);
      for (final zoom in [1.0, 8.0]) {
        final samples = <int>[];
        for (var i = 0; i < 3; i++) {
          final recorder = ui.PictureRecorder();
          MapCanvasPainter(
            layout: MapCanvasLayout.view(
              viewportSize: const Size(800, 600),
              mapWidth: 256,
              mapHeight: 256,
              zoom: zoom,
            ),
            rawTileValues: null,
            showLayoutPower: true,
            powerField: field,
            rangeProjection: ranges,
            onPaintMeasured: (m) => samples.add(m.paintDuration.inMicroseconds),
          ).paint(Canvas(recorder), const Size(800, 600));
          recorder.endRecording().dispose();
        }
        expect(
          samples.every((us) => us < 1000000),
          isTrue,
          reason: 'Debug smoke ceiling only, not release frame acceptance.',
        );
        debugPrint(
          'EDITOR_OVERLAY_SMOKE zoom=$zoom providers=256 rings=192 paintUs=$samples',
        );
      }
    },
  );
}
