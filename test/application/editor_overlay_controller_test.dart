import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_dat_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_analysis_view.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/editor_overlay_fixture.dart';
import '../fixtures/eud_dat_fixture.dart';

void main() {
  late OverlayHarness h;
  setUp(() => h = OverlayHarness());
  tearDown(() => h.dispose());
  test(
    'explicit loads only; selection, history, bytes and resources unchanged',
    () async {
      h.units([basicUnit()]);
      final before = h.h.maps.state.session!,
          depth = h.h.maps.editHistory.undoDepth;
      final bytes = const RawChkEncoder().encode(before.rawDocument);
      h.overlays.configure(
        mode: TerrainAnalysisMode.elevation,
        ranges: true,
        power: true,
      );
      expect(h.overlays.ranges(h.selection()).unknownUnits, 1);
      expect(h.overlays.view!.tileAt(0, 0), isNull);
      expect(h.overlays.powerField, isNull);
      expect(
        h.datGateway.calls +
            h.metadata.calls +
            h.terrainGateway.requests.length,
        0,
      );
      await h.overlays.load();
      expect(h.overlays.error, isNull);
      expect(h.overlays.view!.tileAt(0, 0), isNotNull);
      expect(h.overlays.ranges(h.selection()).rings.length, 2);
      expect(
        h.overlays.ranges(h.selection()).rings.first.x,
        128,
      ); // Not stale selection x=999.
      expect(h.h.maps.state.session, same(before));
      expect(h.h.maps.editHistory.undoDepth, depth);
      expect(const RawChkEncoder().encode(before.rawDocument), bytes);
      expect(before.resourceEdits, isEmpty);
      expect(h.catalog.state.selection, isNull);
      await h.overlays.load();
      expect(h.datGateway.calls, 1);
      expect(h.metadata.calls, 1);
      expect(h.terrainGateway.requests.length, 1);
    },
  );
  test(
    'edit, Undo and owner switch rebuild power without reloading or stale values',
    () async {
      final pylon = basicUnit(type: 156, x: 512, y: 512);
      ByteData.sublistView(pylon).setUint16(14, 1, Endian.little);
      h.units([pylon]);
      h.overlays.configure(power: true);
      await h.overlays.load();
      final field = h.overlays.powerField;
      expect(field!.containsPoint(512, 512), isTrue);
      expect(h.overlays.powerField, same(field));
      h.overlays.configure(owner: 1);
      expect(h.overlays.powerField!.containsPoint(512, 512), isFalse);
      h.overlays.configure(owner: 0);
      h.units([]);
      expect(h.overlays.powerField!.providers, isEmpty);
      h.h.maps.editHistory.undo();
      expect(h.overlays.powerField!.containsPoint(512, 512), isTrue);
      expect(h.metadata.calls, 1);
    },
  );
  test(
    'hidden units suppress rings; invalid selections never dereference records',
    () async {
      h.units([basicUnit()]);
      h.overlays.configure(ranges: true);
      await h.overlays.load();
      final hidden = MapLayerState(
        layers: {
          for (final type in MapLayerType.values)
            type: MapLayerStatus(isVisible: type != MapLayerType.units),
        },
        selections: h.selection().selections,
      );
      expect(h.overlays.ranges(hidden).rings, isEmpty);
      expect(h.overlays.ranges(h.selection(index: 999)).rings, isEmpty);
    },
  );
  test('installation changes invalidate every cached source', () async {
    h.units([basicUnit()]);
    h.overlays.configure(
      mode: TerrainAnalysisMode.elevation,
      ranges: true,
      power: true,
    );
    await h.overlays.load();
    final old = h.overlays.view;
    h.catalog.setInstallationPath(r'C:\Other');
    expect(h.overlays.view, isNot(same(old)));
    expect(h.overlays.view!.tileAt(0, 0), isNull);
    expect(h.overlays.ranges(h.selection()).unknownUnits, 1);
    expect(h.overlays.powerField, isNull);
  });
  test(
    'late DAT reply after map replacement or disposal is never adopted',
    () async {
      h.datGateway.pending = Completer<EudDatReadResult>();
      h.overlays.configure(ranges: true);
      final pending = h.overlays.load();
      h.h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        expectedSession: h.h.maps.state.session,
      );
      h.datGateway.pending!.complete(
        EudDatReadResult(source: syntheticDatSource()),
      );
      await pending;
      expect(h.catalog.eudData, isNull);
      expect(h.overlays.error, isNull);
      expect(h.datGateway.cancelled, isNotEmpty);
      h.datGateway.pending = Completer<EudDatReadResult>();
      final disposed = h.overlays.load();
      await h.overlays.dispose();
      h.datGateway.pending!.complete(
        EudDatReadResult(source: syntheticDatSource()),
      );
      await disposed;
      expect(h.overlays.view, isNull);
    },
  );
  test('failed reads are reported and retryable', () async {
    h.overlays.configure(ranges: true);
    h.datGateway.fail = true;
    await h.overlays.load();
    expect(h.overlays.error, contains('fixture'));
    h.datGateway.fail = false;
    await h.overlays.load();
    expect(h.overlays.error, isNull);
    expect(h.datGateway.calls, 2);
  });
  test(
    'power supplier budget fails closed and source remains reusable',
    () async {
      final pylon = basicUnit(type: 156, x: 512, y: 512);
      ByteData.sublistView(pylon).setUint16(14, 1, Endian.little);
      h.units(List.generate(256, (i) => pylon));
      h.overlays.configure(power: true);
      await h.overlays.load();
      expect(h.overlays.powerField!.providers.length, 256);
      h.units(List.generate(257, (i) => pylon));
      expect(h.overlays.powerField, isNull);
      h.h.maps.editHistory.undo();
      expect(h.overlays.powerField!.providers.length, 256);
      expect(h.metadata.calls, 1);
    },
  );
  test('ambiguous UNIT sections stay unknown without normalization', () async {
    final before = h.editing.source.rawDocument;
    h.editing.apply(
      before,
      before.appendSection(basicSection('UNIT', basicUnit())),
      'Duplicate UNIT',
    );
    h.overlays.configure(power: true, ranges: true);
    await h.overlays.load();
    expect(h.overlays.powerField, isNull);
    expect(h.overlays.ranges(MapLayerState()).rings, isEmpty);
  });
}
