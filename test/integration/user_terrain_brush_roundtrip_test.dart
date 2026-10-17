import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_brush_library.dart';
import 'package:starcraft_map_editor/application/terrain/user_terrain_brush_controller.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/domain/terrain/user_terrain_brush.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_terrain_brush_store.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/document_transfer_fixture.dart';
import '../fixtures/multi_map_fixture.dart';
import '../fixtures/solid_isom_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  for (final profile in TerrainBrushProfile.values) {
    test(
      'persistent ${profile.name} brush reuse and MPQ SaveAs/reopen preserve input',
      () async {
        final root = await Directory.systemTemp.createTemp('user_brush_mpq_');
        addTearDown(() => root.delete(recursive: true));
        final hashes = LocalMapFileFingerprintGateway();
        final f = MultiMapFixture(
          archive: ProcessMapArchiveGateway(helperExecutablePath: helper!),
          fingerprints: hashes,
          files: LocalMapSaveFileGateway(),
        );
        addTearDown(f.dispose);
        final entry = f.addMap();
        final catalog = const TransitionIsomCatalogBuilder().build(
          solidSnapshot(),
        );
        var base = basicDocument();
        if (profile == TerrainBrushProfile.isom) {
          base = const IsomTerrainFill()
              .preview(base, catalog.catalog, solidValue: 16, seed: 0)
              .result;
        }
        final target = profile == TerrainBrushProfile.raw
            ? const NewMapFactory().create(
                NewMapOptions(width: 32, height: 32, rawTileValue: 2),
              )
            : const IsomTerrainFill()
                  .preview(
                    basicDocument(),
                    catalog.catalog,
                    solidValue: 32,
                    seed: 0,
                  )
                  .result;
        adoptTransferDocument(entry.maps, target);
        final source = '${root.path}/source.scx',
            output = '${root.path}/output.scx';
        expect(
          (await entry.saves.saveAs(destinationPath: source)).status,
          SaveMapStatus.saved,
        );
        final fingerprint = await hashes.fingerprint(source);
        final brush = UserTerrainBrush.capture(
          base,
          name: 'Saved',
          region: profile == TerrainBrushProfile.raw
              ? ClipboardRegion(0, 0, 7, 5)
              : ClipboardRegion(0, 0, 31, 31),
          profile: profile,
          catalog: catalog.catalog,
          brush: catalog.brush,
        );
        final store = LocalTerrainBrushStore(Directory('${root.path}/brushes'));
        await TerrainBrushLibrary(store).add(brush);
        final reopenedBrush = (await TerrainBrushLibrary(store).load()).single;
        expect(reopenedBrush.encode(), brush.encode());
        final editing = BasicEditingController(
          maps: entry.maps,
          layers: entry.value.mapLayerController,
        );
        addTearDown(editing.dispose);
        final settings = StarCraftDataAssetSettingsState(
          status: StarCraftDataAssetSettingsStatus.ready,
          configuredPath: r'C:\Synthetic',
        );
        final loader = IsomFillController(
          maps: entry.maps,
          assets: () => settings,
          gateway: SolidSnapshotGateway(),
        );
        final c = UserTerrainBrushController(editing, loader: loader);
        addTearDown(c.dispose);
        if (profile == TerrainBrushProfile.isom) await c.loadCatalog();
        final before = editing.source;
        final preview = c.previewPaste(
          reopenedBrush,
          x: profile == TerrainBrushProfile.raw ? 16 : 0,
          y: profile == TerrainBrushProfile.raw ? 16 : 0,
          mirrorX: profile == TerrainBrushProfile.isom,
          mirrorY: profile == TerrainBrushProfile.isom,
        );
        expect(editing.source, same(before));
        expect(c.apply(preview), isTrue);
        expect(entry.maps.editHistory.undo(), isTrue);
        expect(editing.source, same(before));
        expect(entry.maps.editHistory.redo(), isTrue);
        final expected = const RawChkEncoder().encode(
          editing.source.rawDocument,
        );
        expect(
          (await entry.saves.saveAs(destinationPath: output)).status,
          SaveMapStatus.saved,
        );
        await f.workspace.close(
          entry,
          expectedRevision: entry.revision,
          discardChanges: true,
        );
        final reopened = (await f.workspace.open(path: output))!;
        expect(
          const RawChkEncoder().encode(
            reopened.maps.state.session!.rawDocument,
          ),
          expected,
        );
        expect(await hashes.fingerprint(source), fingerprint);
      },
      skip: !Platform.isWindows || helper == null
          ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
          : false,
    );
  }
}
