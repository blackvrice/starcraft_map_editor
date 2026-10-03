import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/new_map_dialog.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_source_editor.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/ep_script_text_controller.dart';
import 'package:starcraft_map_editor/presentation/settings/default_unit_names.dart';
import 'package:starcraft_map_editor/presentation/settings/default_settings_names.dart';
import 'package:starcraft_map_editor/presentation/settings/unit_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/visual_settings_picker.dart';
import '../test/fixtures/localization_fixture.dart';
import '../test/fixtures/new_map_harness.dart';

/// Native-engine QA, not OS screenshots. Local asset outputs stay ignored.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.toString());
  final installation = Platform.environment['STARCRAFT_TEST_INSTALLATION']!;
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH']!;
  final fixture = LocalizationFixture();
  final terrain = TerrainEditingController(
    openMapController: fixture.workspace.maps,
  );
  final atlas = ProcessStarCraftTileAtlasGateway(helperExecutablePath: helper);
  final catalog = PlacementCatalogController(
    openMapController: fixture.workspace.maps,
    objectEditingController: fixture.editing,
    terrainEditingController: terrain,
    catalogGateway: ProcessStarCraftPlacementCatalogGateway(
      helperExecutablePath: helper,
    ),
    objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
      helperExecutablePath: helper,
    ),
    tileAtlasGateway: atlas,
  );
  catalog.setInstallationPath(installation);
  catalog.synchronizeSession(fixture.workspace.maps.state.session);
  await Future.wait([
    for (final id in [0, 3, 5, 30, 65, 70, 72]) catalog.loadUnitGridPreview(id),
  ]);
  final references = await catalog.loadWeaponReferences();
  final weapons = [0, 1, 2, 3, 4, 5, 6, 7];
  final parentCounts = references.index.subunitUsers(7).length;
  final directory = Directory('.dart_tool/workflow_windows_smoke');
  await directory.create(recursive: true);
  for (final width in [600.0, 1000.0]) {
    final newMap = NewMapHarness()
      ..assets = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: installation,
      );
    final newController = newMap.controller(
      terrainGateway: ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper,
      ),
      tileAtlasGateway: atlas,
    );
    fixture.sources.updateText('$epScriptStarter\nDis');
    final screens = <({String name, Widget widget})>[
      (
        name: 'units',
        widget: UnitSettingsDialog(
          controller: fixture.editing,
          catalogController: catalog,
        ),
      ),
      (
        name: 'unit-grid',
        widget: VisualSettingsPicker(
          ids: [0, 3, 5, 30, 65, 70, 72],
          selected: 5,
          label: (id) => '#$id ${defaultUnitNames[id]}',
          onSelected: (_) {},
          prefix: 'qa-unit',
          catalog: catalog,
        ),
      ),
      (
        name: 'weapon-grid',
        widget: VisualSettingsPicker(
          ids: weapons,
          selected: 7,
          label: (id) => '${defaultWeaponNames[id]} (Weapon #$id)',
          onSelected: (_) {},
          prefix: 'qa-weapon',
          catalog: catalog,
          weapons: true,
        ),
      ),
      (
        name: 'source',
        widget: EudSourceEditor(
          document: fixture.sources.state.document!,
          sourceController: fixture.sources,
        ),
      ),
      (name: 'new-map', widget: NewMapDialog(controller: newController)),
    ];
    for (final screen in screens) {
      final boundary = GlobalKey();
      runApp(
        MaterialApp(
          key: ValueKey('${screen.name}-$width'),
          debugShowCheckedModeBanner: false,
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Center(
            child: OverflowBox(
              minWidth: width,
              maxWidth: width,
              minHeight: 900,
              maxHeight: 900,
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: width,
                  height: 900,
                  child: Scaffold(body: screen.widget),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      if (screen.name == 'source') {
        void visit(Element element) {
          final widget = element.widget;
          if (widget is TextField &&
              widget.key == const Key('eud-source-editor')) {
            widget.controller!.selection = TextSelection.collapsed(
              offset: widget.controller!.text.length,
            );
            widget.focusNode!.requestFocus();
          }
          element.visitChildren(visit);
        }

        visit(boundary.currentContext! as Element);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await WidgetsBinding.instance.endOfFrame;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${directory.path}/${screen.name}-${width.toInt()}.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }
    newController.dispose();
    await newMap.dispose();
  }
  runApp(const SizedBox.shrink());
  await WidgetsBinding.instance.endOfFrame;
  await catalog.dispose();
  await terrain.dispose();
  await fixture.dispose();
  await File(
    '${directory.path}/render_errors.txt',
  ).writeAsString(errors.join('\n'));
  await File('${directory.path}/checks.txt').writeAsString(
    'Native Windows render screens=10; unit previews loaded; weapon parent references=$parentCounts\n',
  );
  exit(errors.isEmpty ? 0 : 1);
}
