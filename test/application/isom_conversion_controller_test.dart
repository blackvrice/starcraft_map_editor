import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/isom_conversion_controller.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/application/ports/isom_terrain_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_conversion.dart';
import '../fixtures/isom_conversion_fixture.dart';
import '../fixtures/new_map_harness.dart';

void prepare(NewMapHarness h) {
  h.maps.createNew(
    NewMapOptions(width: 32, height: 32, rawTileValue: 0),
    expectedSession: h.maps.state.session,
  );
  final s = h.maps.state.session!;
  final doc = isomFixture();
  h.maps.adoptEditedSession(
    OpenedMapSession(
      extractedMap: s.extractedMap,
      rawDocument: doc,
      metadataViews: h.maps.metadataViewDecoder.decode(doc),
      stringViews: s.stringViews,
      terrainViews: h.maps.terrainViewDecoder.decode(doc),
      objectViews: s.objectViews,
      sourceFingerprint: null,
      diagnostics: s.diagnostics,
      resourceEdits: {
        r'staredit\wav\pending.wav': [1, 2, 3],
      },
    ),
  );
}

class Catalog implements IsomTerrainCatalogGateway {
  Completer<IsomTerrainCatalog>? pending;
  @override
  Future<IsomTerrainCatalog> load({required int tileset}) async =>
      pending == null ? isomCatalog() : await pending!.future;
}

void main() {
  test(
    'explicit preview does not mutate; apply preserves resources and is one Undo command',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      prepare(h);
      final c = IsomConversionController(maps: h.maps, catalogs: Catalog());
      final before = h.maps.state.session;
      final p = await c.preview(seed: 1);
      expect(h.maps.state.session, same(before));
      expect(h.maps.editHistory.undoDepth, 0);
      expect(c.apply(p), isTrue);
      final after = h.maps.state.session!;
      expect(after.resourceEdits, same(before!.resourceEdits));
      expect(after.extractedMap, same(before.extractedMap));
      expect(h.maps.editHistory.undoDepth, 1);
      expect(() => c.apply(p), throwsStateError);
      h.maps.editHistory.undo();
      expect(h.maps.state.session, same(before));
      h.maps.editHistory.redo();
      expect(h.maps.state.session, same(after));
      final noChange = await c.preview(seed: 99);
      expect(c.apply(noChange), isFalse);
      expect(h.maps.editHistory.undoDepth, 1);
    },
  );
  test(
    'late provider completion and active brush cannot apply stale work',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      prepare(h);
      final provider = Catalog()..pending = Completer();
      final c = IsomConversionController(maps: h.maps, catalogs: provider);
      final future = c.preview(seed: 1);
      final expectation = expectLater(future, throwsStateError);
      c.invalidate();
      provider.pending!.complete(isomCatalog());
      await expectation;
      provider.pending = null;
      final p = await c.preview(seed: 1);
      final owner = Object();
      h.maps.editHistory.beginTransaction(owner);
      expect(() => c.apply(p), throwsStateError);
      h.maps.editHistory.endTransaction(owner);
      prepare(h);
      expect(() => c.apply(p), throwsStateError);
    },
  );
}
