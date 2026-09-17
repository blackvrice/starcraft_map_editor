import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/presentation/placement/placement_catalog_pane.dart';

const _count = 2000;
const _side = 32;
const _bytesPerImage = _side * _side * 4;

void main() {
  testWidgets('catalog thumbnails stay virtualized and release image handles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _ThumbnailCatalog();
    addTearDown(controller.dispose);
    final live = <ui.Image>{};
    var peak = 0;
    var created = 0;
    final previousCreate = ui.Image.onCreate;
    final previousDispose = ui.Image.onDispose;
    ui.Image.onCreate = (image) {
      previousCreate?.call(image);
      live.add(image);
      created++;
      if (live.length > peak) peak = live.length;
    };
    ui.Image.onDispose = (image) {
      live.remove(image);
      previousDispose?.call(image);
    };
    addTearDown(() {
      ui.Image.onCreate = previousCreate;
      ui.Image.onDispose = previousDispose;
    });

    Future<void> finishDecoding() async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    final watch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacementCatalogPane(controller: controller)),
      ),
    );
    await finishDecoding();
    expect(find.byType(RawImage), findsWidgets);
    final initialHandles = live.length;
    expect(initialHandles, greaterThan(0));
    for (var step = 0; step < 12; step++) {
      await tester.drag(
        find.byKey(const Key('placement-catalog-grid')),
        const Offset(0, -600),
      );
      await finishDecoding();
    }
    expect(created, greaterThan(initialHandles));
    expect(peak, lessThan(StarCraftPlacementCatalogRequest.maximumLimit));
    final rawBytes = controller.state.items.fold<int>(
      0,
      (sum, item) => sum + item.thumbnailRgba!.lengthInBytes,
    );
    expect(rawBytes, _count * _bytesPerImage);
    await tester.enterText(
      find.byKey(const Key('placement-catalog-search')),
      '#1999',
    );
    await finishDecoding();
    expect(find.byType(RawImage), findsOneWidget);
    // RawImage's render object owns a cloned handle alongside the decoded one.
    expect(live.length, inInclusiveRange(1, 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await finishDecoding();
    expect(
      live,
      isEmpty,
      reason: 'closing the pane must dispose every image handle',
    );
    // Raw page bytes are retained by the controller for reopening the catalog.
    expect(controller.state.items, hasLength(_count));
    // Closing before the asynchronous decoder finishes must release late images.
    controller.setQuery('');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacementCatalogPane(controller: controller)),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await finishDecoding();
    expect(live, isEmpty, reason: 'late decoder results must also be disposed');
    watch.stop();
    debugPrint(
      'placement-catalog thumbnails (debug): rawBytes=$rawBytes '
      'initialHandles=$initialHandles peakHandles=$peak '
      'handlePixelUpperBound=${peak * _bytesPerImage} created=$created '
      'liveAfterClose=${live.length} harnessMs=${watch.elapsedMilliseconds}',
    );
    expect(tester.takeException(), isNull);
  });
}

class _ThumbnailCatalog implements PlacementCatalogController {
  _ThumbnailCatalog() {
    final items = List.generate(
      _count,
      (id) => PlacementCatalogItem(
        entry: StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.doodad(
            tileset: StarCraftTilesetAssetSet.badlands,
            doodadId: id,
            startTileGroup: id,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.unsupported,
          issue: StarCraftPlacementCatalogIssue(
            code: 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
            message: 'Synthetic thumbnails are not placement recipes.',
          ),
        ),
        thumbnailRgba: Uint8List.fromList(List.filled(_bytesPerImage, 255)),
        thumbnailWidth: _side,
        thumbnailHeight: _side,
      ),
    );
    state = PlacementCatalogState(
      kind: StarCraftPlacementKind.doodad,
      items: items,
      totalEntries: items.length,
    );
  }
  final _events = StreamController<PlacementCatalogState>.broadcast(sync: true);
  @override
  late PlacementCatalogState state;
  @override
  Stream<PlacementCatalogState> get changes => _events.stream;
  @override
  void setQuery(String query) {
    state = PlacementCatalogState(
      kind: state.kind,
      items: state.items,
      totalEntries: state.totalEntries,
      query: query,
    );
    _events.add(state);
  }

  @override
  Future<void> dispose() => _events.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
