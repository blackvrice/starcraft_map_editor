// Run only with: flutter build windows --profile --target tool/catalog_profile.dart
// Pass --dart-define=CATALOG_PROFILE_OUTPUT=<new absolute JSON path>.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/presentation/placement/placement_catalog_pane.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const outputPath = String.fromEnvironment('CATALOG_PROFILE_OUTPUT');
  if (!kProfileMode ||
      outputPath.isEmpty ||
      !File(outputPath).isAbsolute ||
      File(outputPath).existsSync()) {
    stderr.writeln(
      'Requires profile mode and a new absolute CATALOG_PROFILE_OUTPUT path.',
    );
    exit(2);
  }
  final output = File(outputPath);
  final frames = <ui.FrameTiming>[];
  final images = <ui.Image>{};
  var peakHandles = 0;
  ui.Image.onCreate = (image) {
    images.add(image);
    if (images.length > peakHandles) peakHandles = images.length;
  };
  ui.Image.onDispose = images.remove;
  WidgetsBinding.instance.addTimingsCallback(frames.addAll);
  final paneKey = GlobalKey();
  final controller = _ProfileCatalog();
  final report = <String, Object?>{
    'mode': 'profile',
    'fixture': 'synthetic-2000-rgba-32x32',
    'os': Platform.operatingSystemVersion,
    'dart': Platform.version,
  };
  var status = 0;
  try {
    await (() async {
      final first = Stopwatch()..start();
      runApp(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              key: paneKey,
              child: PlacementCatalogPane(controller: controller),
            ),
          ),
        ),
      );
      await _waitFor(
        () => _elements(paneKey).any(
          (e) => e.widget is RawImage && (e.widget as RawImage).image != null,
        ),
      );
      first.stop();
      report['firstImageMs'] = first.elapsedMilliseconds;
      report['builtItems'] = _elements(paneKey)
          .where(
            (e) =>
                e.widget is InkWell &&
                e.widget.key.toString().contains('placement-catalog-item-'),
          )
          .length;
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      report['physicalWidth'] = view.physicalSize.width;
      report['physicalHeight'] = view.physicalSize.height;
      report['devicePixelRatio'] = view.devicePixelRatio;
      final search = Stopwatch()..start();
      controller.setQuery('#255');
      await _waitFor(
        () =>
            _elements(paneKey)
                .where(
                  (e) =>
                      e.widget is RawImage &&
                      (e.widget as RawImage).image != null,
                )
                .length ==
            1,
      );
      report['searchMs'] = search.elapsedMilliseconds;
      controller.setQuery('');
      await WidgetsBinding.instance.endOfFrame;
      final scrollable = _elements(paneKey)
          .where((e) => e is StatefulElement && e.state is ScrollableState)
          .cast<StatefulElement>()
          .map((e) => e.state as ScrollableState)
          .firstWhere((s) => s.position.maxScrollExtent > 0);
      final scroll = Stopwatch()..start();
      for (var step = 0; step < 12; step++) {
        final position = scrollable.position;
        await position.animateTo(
          (position.pixels + 600).clamp(0.0, position.maxScrollExtent),
          duration: const Duration(milliseconds: 200),
          curve: Curves.linear,
        );
        await WidgetsBinding.instance.endOfFrame;
      }
      report['scroll12Ms'] = scroll.elapsedMilliseconds;
      report['loadedEntries'] = controller.state.items.length;
      report['retainedRgbaBytes'] = controller.state.items.fold<int>(
        0,
        (n, item) => n + item.thumbnailRgba!.length,
      );
      runApp(const SizedBox.shrink());
      await WidgetsBinding.instance.endOfFrame;
      await _waitFor(() => images.isEmpty);
      // Engine timings are delivered in batches; allow the final batch to arrive.
      await Future<void>.delayed(const Duration(seconds: 1));
      report['peakImageHandles'] = peakHandles;
      report['liveImageHandlesAfterClose'] = images.length;
      report['frameCount'] = frames.length;
      report['buildP95Us'] = _p95(
        frames.map((f) => f.buildDuration.inMicroseconds),
      );
      report['rasterP95Us'] = _p95(
        frames.map((f) => f.rasterDuration.inMicroseconds),
      );
      if (frames.isEmpty ||
          (report['builtItems'] as int) >= 128 ||
          controller.state.items.length <= 256) {
        throw StateError(
          'Frame collection, virtualization, or paging check failed.',
        );
      }
      report['passed'] = true;
    })().timeout(const Duration(seconds: 60));
  } catch (error, stack) {
    status = 1;
    report['passed'] = false;
    report['error'] = '$error';
    report['stack'] = '$stack';
  } finally {
    await controller.dispose();
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
  }
  exit(status);
}

List<Element> _elements(GlobalKey key) {
  final result = <Element>[];
  void visit(Element element) {
    result.add(element);
    element.visitChildElements(visit);
  }

  final context = key.currentContext;
  if (context is Element) visit(context);
  return result;
}

Future<void> _waitFor(bool Function() ready) async {
  final watch = Stopwatch()..start();
  while (!ready()) {
    if (watch.elapsed > const Duration(seconds: 15)) {
      throw TimeoutException('UI condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await WidgetsBinding.instance.endOfFrame;
  }
}

int _p95(Iterable<int> values) {
  final sorted = values.toList()..sort();
  return sorted.isEmpty ? 0 : sorted[(sorted.length * 0.95).ceil() - 1];
}

class _ProfileCatalog implements PlacementCatalogController {
  final _events = StreamController<PlacementCatalogState>.broadcast(sync: true);
  final _items = List.generate(
    2000,
    (id) => PlacementCatalogItem(
      entry: StarCraftPlacementCatalogEntry(
        key: StarCraftPlacementCatalogKey.doodad(
          tileset: StarCraftTilesetAssetSet.jungle,
          doodadId: id,
          startTileGroup: id,
        ),
        source: StarCraftPlacementCatalogSource.localData,
        availability: StarCraftPlacementAvailability.unsupported,
        issue: StarCraftPlacementCatalogIssue(
          code: 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
          message: 'Synthetic profile fixture.',
        ),
      ),
      thumbnailRgba: Uint8List.fromList(List.filled(32 * 32 * 4, 255)),
      thumbnailWidth: 32,
      thumbnailHeight: 32,
    ),
  );
  _ProfileCatalog() {
    state = PlacementCatalogState(
      kind: StarCraftPlacementKind.doodad,
      items: _items.take(256),
      totalEntries: _items.length,
    );
  }
  @override
  late PlacementCatalogState state;
  @override
  Stream<PlacementCatalogState> get changes => _events.stream;
  @override
  void setQuery(String query) {
    state = PlacementCatalogState(
      kind: state.kind,
      items: state.items,
      totalEntries: _items.length,
      query: query,
    );
    _events.add(state);
  }

  @override
  Future<bool> loadMore() async {
    if (!state.hasMore) return false;
    state = PlacementCatalogState(
      kind: state.kind,
      items: _items.take(state.items.length + 256),
      totalEntries: _items.length,
      query: state.query,
    );
    _events.add(state);
    return true;
  }

  @override
  Future<void> dispose() => _events.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
