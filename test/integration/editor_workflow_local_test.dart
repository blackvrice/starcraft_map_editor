import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/safe_eud_build_pipeline.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/placement/object_placement_factory.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/bundled_eud_tool.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_build_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/ep_script_text_controller.dart';
import '../fixtures/new_map_harness.dart';

void main() {
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  final installation = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  final archiveHelper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  final tool = Platform.environment['EUDDRAFT_TEST_INSTALLATION'];
  final assetsSkip =
      !Platform.isWindows || helper == null || installation == null;

  test(
    'tank, siege tank and goliath compose their verified turrets and place one UNIT',
    () async {
      final catalog = ProcessStarCraftPlacementCatalogGateway(
        helperExecutablePath: helper!,
      );
      final renderer = ProcessStarCraftObjectAtlasGateway(
        helperExecutablePath: helper,
      );
      for (final id in [3, 5, 30]) {
        final page = await catalog.list(
          StarCraftPlacementCatalogRequest(
            operationId: 'parent-$id',
            installationPath: installation!,
            kind: StarCraftPlacementKind.unit,
            tileset: StarCraftTilesetAssetSet.badlands,
            offset: id,
            limit: 1,
          ),
        );
        expect(page.isSuccess, isTrue, reason: '${page.diagnostics}');
        final parent = page.entries.single;
        expect(parent.isPlaceable, isTrue);
        final capability = parent.unitCapability!;
        expect(capability.isSubunit, isFalse);
        final subunit = capability.weaponReferences!.subunit1;
        final subPage = await catalog.list(
          StarCraftPlacementCatalogRequest(
            operationId: 'turret-$id',
            installationPath: installation,
            kind: StarCraftPlacementKind.unit,
            tileset: StarCraftTilesetAssetSet.badlands,
            offset: subunit,
            limit: 1,
          ),
        );
        expect(subPage.entries.single.unitCapability!.isSubunit, isTrue);
        expect(subPage.entries.single.isPlaceable, isFalse);
        final composed = await renderer.render(
          StarCraftObjectAtlasRequest(
            operationId: 'compose-$id',
            installationPath: installation,
            tileset: StarCraftTilesetAssetSet.badlands,
            objects: [
              StarCraftObjectGraphicKey(
                kind: StarCraftObjectGraphicKind.unit,
                id: id,
                playerColor: 0,
              ),
              StarCraftObjectGraphicKey(
                kind: StarCraftObjectGraphicKind.unit,
                id: subunit,
                playerColor: 0,
              ),
            ],
          ),
        );
        expect(composed.isSuccess, isTrue, reason: '${composed.diagnostics}');
        expect(composed.unsupportedObjects, isEmpty);
        final body = composed.entries.firstWhere((e) => e.key.id == id);
        final turret = composed.entries.firstWhere((e) => e.key.id == subunit);
        final raw = await renderer.render(
          StarCraftObjectAtlasRequest(
            operationId: 'base-$id',
            installationPath: installation,
            tileset: StarCraftTilesetAssetSet.badlands,
            objects: [
              StarCraftObjectGraphicKey(
                kind: StarCraftObjectGraphicKind.sprite,
                id: body.spriteId,
                playerColor: 0,
              ),
            ],
          ),
        );
        expect(raw.entries, hasLength(1));
        final base = raw.entries.single;
        var turretPixels = 0, changedPixels = 0;
        for (var y = 0; y < body.height; y++) {
          for (var x = 0; x < body.width; x++) {
            final originX = x - body.anchorX, originY = y - body.anchorY;
            List<int> pixel(StarCraftObjectAtlasEntry e) {
              final px = originX + e.anchorX, py = originY + e.anchorY;
              if (px < 0 || px >= e.width || py < 0 || py >= e.height) {
                return [0, 0, 0, 0];
              }
              return e.rgbaBytes.sublist(
                (py * e.width + px) * 4,
                (py * e.width + px + 1) * 4,
              );
            }

            final lower = pixel(base),
                upper = pixel(turret),
                actual = pixel(body);
            expect(
              actual,
              upper[3] == 255 ? upper : lower,
              reason: 'unit $id pixel $x,$y',
            );
            if (upper[3] == 255) turretPixels++;
            if (actual.toString() != lower.toString()) changedPixels++;
          }
        }
        expect(turretPixels, greaterThan(0));
        expect(changedPixels, greaterThan(0));
        final record = const UnitPlacementFactory().create(
          capability: capability,
          unitId: id,
          owner: 0,
          x: 96,
          y: 96,
          classId: 1,
        );
        expect(record.bytes, hasLength(36));
        final decoded = const ChkObjectViewDecoder().decode(
          RawChkDocument(
            sections: [
              RawChkSection(
                nameBytes: 'UNIT'.codeUnits,
                declaredLength: 36,
                payload: record.bytes,
                sourceOffset: 0,
              ),
            ],
            sourceLength: 44,
          ),
        );
        expect(decoded.unitSections.single.units.single.unitType, id);
      }
    },
    skip: assetsSkip ? 'Requires local SC:R data/helper.' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'all eight terrain-first maps render and reopen native MPQ byte exactly',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.assets = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: installation!,
      );
      final atlas = ProcessStarCraftTileAtlasGateway(
        helperExecutablePath: helper!,
      );
      final terrain = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper,
      );
      final archive = ProcessMapArchiveGateway(
        helperExecutablePath: archiveHelper!,
      );
      final root = await Directory.systemTemp.createTemp(
        'workflow-new-terrain-',
      );
      addTearDown(() => root.delete(recursive: true));
      for (final tileset in StarCraftTilesetAssetSet.values) {
        final c = h.controller(
          terrainGateway: terrain,
          tileAtlasGateway: atlas,
        );
        addTearDown(c.dispose);
        final catalog = await c.loadTerrain(tileset);
        final type = catalog.shapes.keys.firstWhere(
          (t) => catalog.catalog.pairs.any(
            (p) => p.terrainType == t && p.members.length > 1,
          ),
        );
        final options = c.terrainOptions(
          NewMapOptions(
            width: 32,
            height: 32,
            tileset: ChkTileset.values[tileset.rawValue],
            rawTileValue: 0,
          ),
          type,
          159,
        );
        final session = c.create(options);
        expect(session.sourcePath, isNull);
        final bytes = session.rawDocument.sections
            .singleWhere((s) => s.name == 'TILE')
            .payload;
        final data = ByteData.sublistView(Uint8List.fromList(bytes));
        final values = {
          for (var i = 0; i < data.lengthInBytes; i += 2)
            data.getUint16(i, Endian.little),
        };
        expect(values.length, greaterThan(2));
        final rendered = await atlas.render(
          StarCraftTileAtlasRequest(
            installationPath: installation,
            tileset: tileset,
            rawValues: values.toList()..sort(),
          ),
        );
        expect(
          rendered.isSuccess,
          isTrue,
          reason: rendered.diagnostics
              .map((d) => '${d.code}: ${d.message}\n${d.rawDetails ?? ''}')
              .join('\n'),
        );
        expect(rendered.unsupportedRawValues, isEmpty);
        final chk = const RawChkEncoder().encode(session.rawDocument);
        final path = '${root.path}/${tileset.fileStem}.scx';
        final written = await archive.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'workflow-write-${tileset.fileStem}',
            sourcePath: null,
            temporaryOutputPath: path,
            scenarioChkBytes: chk,
            timeout: const Duration(seconds: 30),
          ),
        );
        expect(written.isSuccess, isTrue, reason: '${written.diagnostics}');
        final reopened = await archive.open(
          MapArchiveOpenRequest(
            operationId: 'workflow-open-${tileset.fileStem}',
            sourcePath: path,
            timeout: const Duration(seconds: 30),
          ),
        );
        expect(reopened.extractedMap!.scenarioChkBytes, chk);
      }
    },
    skip: assetsSkip || archiveHelper == null
        ? 'Requires local SC:R and archive helpers.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'editor starter compiles with bundled euddraft without modifying inputs',
    () async {
      final root = await Directory.systemTemp.createTemp('workflow-eps-');
      addTearDown(() => root.delete(recursive: true));
      final base = await File(
        'test/fixtures/maps/eud_smoke/eud-smoke-self-authored.scx',
      ).copy('${root.path}/base.scx');
      final before = await base.readAsBytes();
      final sourceRoot = await Directory('${root.path}/src').create();
      final entry = await File(
        '${sourceRoot.path}/starter.eps',
      ).writeAsString(epScriptStarter);
      final inspection = await BundledEudTool.inspector().inspect(
        EudToolInspectionRequest(bundledPath: tool),
      );
      expect(inspection.isReady, isTrue);
      final pipeline = SafeEudBuildPipeline(
        toolInspector: BundledEudTool.inspector(),
        compilerGateway: ProcessEudCompilerGateway(),
        archiveGateway: ProcessMapArchiveGateway(
          helperExecutablePath: archiveHelper!,
        ),
        fingerprintGateway: LocalMapFileFingerprintGateway(),
        buildFileGateway: LocalEudBuildFileGateway(),
      );
      final output = '${root.path}/output.scx';
      final events = await pipeline
          .build(
            EudBuildPlan(
              buildId: 'workflow-starter',
              configuration: EudBuildConfiguration(
                baseMapPath: base.path,
                sourceRootPath: sourceRoot.path,
                entrySourcePath: entry.path,
                outputMapPath: output,
              ),
              tool: inspection.tool!,
              timeout: const Duration(minutes: 1),
            ),
          )
          .toList();
      expect(
        events.last.kind,
        EudBuildEventKind.succeeded,
        reason: events
            .map((e) => e.text ?? e.diagnostic?.toString() ?? '')
            .join('\n'),
      );
      expect(await File(output).exists(), isTrue);
      expect(await base.readAsBytes(), before);
      expect(await entry.readAsString(), epScriptStarter);
    },
    skip: !Platform.isWindows || tool == null || archiveHelper == null
        ? 'Requires bundled euddraft and archive helper.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
