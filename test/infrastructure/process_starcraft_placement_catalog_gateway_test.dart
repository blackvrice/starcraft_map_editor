import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/placement/unit_resource_distance.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/object_placement_factory.dart';
import 'package:starcraft_map_editor/domain/placement/unit_resource_distance_catalog.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';

void main() {
  group('ProcessStarCraftPlacementCatalogGateway', () {
    late String powershellExecutable;
    late String fakeHelperScript;

    setUpAll(() async {
      powershellExecutable = await _findPowerShellExecutable();
      fakeHelperScript = File(
        'test/fixtures/helpers/fake_starcraft_data_helper.ps1',
      ).absolute.path;
    });

    ProcessStarCraftPlacementCatalogGateway createGateway({
      Duration timeout = const Duration(seconds: 10),
      int maximumProcessOutputBytes = 256 * 1024,
    }) => ProcessStarCraftPlacementCatalogGateway(
      helperExecutablePath: powershellExecutable,
      helperArguments: [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        fakeHelperScript,
      ],
      timeout: timeout,
      maximumProcessOutputBytes: maximumProcessOutputBytes,
      additionalInheritedEnvironmentKeys: Platform.environment.keys.toList(
        growable: false,
      ),
    );

    StarCraftPlacementCatalogRequest requestFor(
      String scenario, {
      String operationId = 'catalog-test',
      int offset = 0,
      int limit = 3,
      StarCraftPlacementKind kind = StarCraftPlacementKind.tile,
    }) => StarCraftPlacementCatalogRequest(
      operationId: operationId,
      installationPath: 'C:\\Games\\$scenario',
      kind: kind,
      tileset: StarCraftTilesetAssetSet.jungle,
      offset: offset,
      limit: limit,
    );

    test(
      'reads metadata without previews and rejects invalid or old metadata responses',
      () async {
        for (final scenario in [
          'StarCraft',
          'weapon-invalid',
          'weapon-old-helper',
        ]) {
          final page = await createGateway().list(
            StarCraftPlacementCatalogRequest(
              operationId: 'weapon-test',
              installationPath: 'C:\\Games\\$scenario',
              kind: StarCraftPlacementKind.unit,
              tileset: StarCraftTilesetAssetSet.badlands,
              limit: 228,
              unitMetadataOnly: true,
            ),
          );
          expect(
            page.isSuccess,
            scenario == 'StarCraft',
            reason: page.diagnostics
                .map((d) => '${d.code} ${d.rawDetails}')
                .join('\n'),
          );
          if (page.isSuccess) {
            expect(page.entries, hasLength(228));
            expect(
              page.entries.first.unitCapability!.weaponReferences!.ground,
              7,
            );
            expect(
              page.entries[1].unitCapability!.weaponReferences!.subunit1,
              0,
            );
            expect(page.totalMetadataBytes, 19876);
          } else {
            expect(
              page.diagnostics.single.code,
              StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
            );
          }
        }
      },
    );
    for (final scenario in [
      'resource-neither',
      'resource-depot',
      'resource-container',
      'resource-both',
      'resource-old',
      'resource-null',
      'resource-version',
      'resource-object',
      'resource-mismatch',
      'resource-isDepot-type',
      'resource-isDepot-missing',
      'resource-isResource-type',
      'resource-isResource-missing',
    ]) {
      test('validates optional versioned resource roles $scenario', () async {
        for (final metadataOnly in [false, true]) {
          final page = await createGateway().list(
            StarCraftPlacementCatalogRequest(
              operationId: 'resource-profile-test',
              installationPath: 'C:\\Games\\$scenario',
              kind: StarCraftPlacementKind.unit,
              tileset: StarCraftTilesetAssetSet.badlands,
              offset: 8,
              limit: 1,
              unitMetadataOnly: metadataOnly,
            ),
          );
          final legacy =
              scenario == 'resource-old' || scenario == 'resource-null';
          final valid = [
            'resource-neither',
            'resource-depot',
            'resource-container',
            'resource-both',
          ].contains(scenario);
          expect(
            page.isSuccess,
            legacy || valid,
            reason: '${page.diagnostics}',
          );
          if (page.isSuccess) {
            final cap = page.entries.single.unitCapability!;
            expect(page.entries.single.isPlaceable, isTrue);
            if (legacy) {
              expect(cap.resourceProfile, isNull);
            } else {
              final profile = cap.resourceProfile!;
              expect(
                profile.isDepot,
                ['resource-depot', 'resource-both'].contains(scenario),
              );
              expect(
                profile.isResource,
                ['resource-container', 'resource-both'].contains(scenario),
              );
              expect(profile.isResource, cap.isResourceContainer);
            }
          } else {
            expect(
              page.diagnostics.single.code,
              StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
            );
          }
        }
      }, skip: !Platform.isWindows);
    }
    test('lists a validated contiguous Tile page', () async {
      final page = await createGateway().list(requestFor('StarCraft'));

      expect(page.isSuccess, isTrue, reason: page.diagnostics.toString());
      expect(page.totalEntries, 260);
      expect(page.entries.map((entry) => entry.key.id), [0, 1, 2]);
      expect(page.entries.map((entry) => entry.displayName), [
        'Tile #0',
        'Tile #1',
        'Tile #2',
      ]);
      expect(page.nextOffset, 3);
      expect(page.storageProduct, 's1');
      expect(page.storageBuildNumber, 13515);
      expect(page.helperVersion, '0.13.0');
      expect(page.totalMetadataBytes, 1048576);
    }, skip: !Platform.isWindows);

    final realHelper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
    final realInstallation =
        Platform.environment['STARCRAFT_TEST_INSTALLATION'];
    test(
      'local resource roles cover classic DAT and agree across metadata and graphics',
      () async {
        final gateway = ProcessStarCraftPlacementCatalogGateway(
          helperExecutablePath: realHelper!,
        );
        final metadata = await gateway.list(
          StarCraftPlacementCatalogRequest(
            operationId: 'real-resource-metadata',
            installationPath: realInstallation!,
            kind: StarCraftPlacementKind.unit,
            tileset: StarCraftTilesetAssetSet.badlands,
            limit: 228,
            unitMetadataOnly: true,
          ),
        );
        expect(metadata.isSuccess, isTrue, reason: '${metadata.diagnostics}');
        expect(metadata.entries, hasLength(228));
        for (final entry in metadata.entries) {
          final cap = entry.unitCapability!;
          expect(cap.resourceProfile, isNotNull);
          expect(cap.resourceProfile!.isResource, cap.isResourceContainer);
          expect(entry.hasPreview, isFalse);
        }
        final depot = metadata.entries[106].unitCapability!;
        final resource = metadata.entries[188].unitCapability!;
        expect(depot.resourceProfile!.isDepot, isTrue);
        expect(depot.resourceProfile!.isResource, isFalse);
        expect(resource.resourceProfile!.isResource, isTrue);
        expect(resource.isGasResourceContainer, isTrue);
        expect(
          metadata.entries.first.unitCapability!.resourceProfile!.isDepot,
          isFalse,
        );
        final graphics = await gateway.list(
          StarCraftPlacementCatalogRequest(
            operationId: 'real-resource-graphics',
            installationPath: realInstallation,
            kind: StarCraftPlacementKind.unit,
            tileset: StarCraftTilesetAssetSet.badlands,
            offset: 106,
            limit: 1,
          ),
        );
        expect(graphics.isSuccess, isTrue, reason: '${graphics.diagnostics}');
        expect(
          (
            graphics.storageProduct,
            graphics.storageBuildNumber,
            graphics.helperVersion,
            graphics.cascLibRevision,
          ),
          (
            metadata.storageProduct,
            metadata.storageBuildNumber,
            metadata.helperVersion,
            metadata.cascLibRevision,
          ),
        );
        expect(
          graphics.entries.single.unitCapability!.resourceProfile!.isDepot,
          depot.resourceProfile!.isDepot,
        );
        expect(
          graphics.entries.single.unitCapability!.resourceProfile!.isResource,
          depot.resourceProfile!.isResource,
        );
        for (final x in [1024, 1600]) {
          expect(
            UnitResourceDistance.checkPair(
              candidateRole: depot.resourceProfile,
              existingRole: resource.resourceProfile,
              candidateBounds: depot.collisionProfile!.boundsAt(1024, 1024),
              existingBounds: resource.collisionProfile!.boundsAt(x, 1024),
              mapWidthTiles: 64,
              mapHeightTiles: 64,
            ),
            x == 1024
                ? UnitResourceDistanceCheck.tooClose
                : UnitResourceDistanceCheck.clear,
          );
          final record = const UnitPlacementFactory()
              .create(
                capability: resource,
                unitId: resource.unitId,
                owner: 11,
                x: x,
                y: 1024,
                classId: 1,
              )
              .bytes;
          final bytes = Uint8List(8 + record.length)
            ..setRange(0, 4, 'UNIT'.codeUnits)
            ..setRange(8, 8 + record.length, record);
          ByteData.sublistView(
            bytes,
          ).setUint32(4, record.length, Endian.little);
          final before = Uint8List.fromList(bytes);
          final units = const ChkObjectViewDecoder()
              .decode(const RawChkParser().parse(bytes).document!)
              .unitSections
              .single
              .units;
          expect(
            UnitResourceDistanceCatalog({
              for (final entry in metadata.entries)
                entry.key.id: entry.unitCapability!,
            }).check(
              candidate: graphics.entries.single.unitCapability!,
              x: 1024,
              y: 1024,
              mapWidthTiles: 64,
              mapHeightTiles: 64,
              existing: units,
            ),
            x == 1024
                ? UnitResourceDistanceCatalogCheck.tooClose
                : UnitResourceDistanceCatalogCheck.clear,
          );
          expect(bytes, orderedEquals(before));
        }
      },
      skip:
          !Platform.isWindows || realHelper == null || realInstallation == null,
    );
    test(
      'local collision metadata is available for all classic units without graphics',
      () async {
        final page =
            await ProcessStarCraftPlacementCatalogGateway(
              helperExecutablePath: realHelper!,
            ).list(
              StarCraftPlacementCatalogRequest(
                operationId: 'real-collision-profiles',
                installationPath: realInstallation!,
                kind: StarCraftPlacementKind.unit,
                tileset: StarCraftTilesetAssetSet.badlands,
                limit: 228,
                unitMetadataOnly: true,
              ),
            );
        expect(page.isSuccess, isTrue, reason: '${page.diagnostics}');
        expect(page.entries, hasLength(228));
        for (final entry in page.entries) {
          final profile = entry.unitCapability!.collisionProfile!;
          for (final offset in [
            profile.left,
            profile.up,
            profile.right,
            profile.down,
          ]) {
            expect(offset, inInclusiveRange(0, 65535));
          }
          expect(entry.hasPreview, isFalse);
        }
        expect(
          page.entries[0].unitCapability!.collisionProfile!.isFlyer,
          isFalse,
        );
        expect(
          page.entries[8].unitCapability!.collisionProfile!.isFlyer,
          isTrue,
        );
        expect(
          page.entries[106].unitCapability!.collisionProfile!.left,
          greaterThan(0),
        );
      },
      skip:
          !Platform.isWindows || realHelper == null || realInstallation == null,
    );

    for (final scenario in [
      'StarCraft',
      'collision-old',
      'collision-null',
      'collision-limits',
      'collision-version',
      'collision-flyer',
      'collision-object',
      for (final axis in ['left', 'up', 'right', 'down'])
        for (final failure in ['negative', 'overflow', 'type', 'missing'])
          'collision-$axis-$failure',
    ]) {
      test('validates optional collision profile $scenario', () async {
        for (final metadataOnly in [false, true]) {
          final page = await createGateway().list(
            StarCraftPlacementCatalogRequest(
              operationId: 'collision-profile-test',
              installationPath: 'C:\\Games\\$scenario',
              kind: StarCraftPlacementKind.unit,
              tileset: StarCraftTilesetAssetSet.badlands,
              offset: 8,
              limit: 1,
              unitMetadataOnly: metadataOnly,
            ),
          );
          final legacy =
              scenario == 'collision-old' || scenario == 'collision-null';
          final valid =
              scenario == 'StarCraft' || scenario == 'collision-limits';
          expect(
            page.isSuccess,
            legacy || valid,
            reason: '${page.diagnostics}',
          );
          if (page.isSuccess) {
            expect(page.entries.single.isPlaceable, isTrue);
            final profile =
                page.entries.single.unitCapability!.collisionProfile;
            if (legacy) {
              expect(profile, isNull);
            } else {
              final limits = scenario == 'collision-limits';
              expect([
                profile!.left,
                profile.up,
                profile.right,
                profile.down,
              ], limits ? [0, 65535, 65535, 0] : [3, 5, 7, 9]);
              expect(profile.isFlyer, !limits);
            }
          } else {
            expect(
              page.diagnostics.single.code,
              StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
            );
          }
        }
      }, skip: !Platform.isWindows);
    }
    test(
      'local units.dat metadata carries validated building boxes independently of previews',
      () async {
        final page =
            await ProcessStarCraftPlacementCatalogGateway(
              helperExecutablePath: realHelper!,
            ).list(
              StarCraftPlacementCatalogRequest(
                operationId: 'real-building-boxes',
                installationPath: realInstallation!,
                kind: StarCraftPlacementKind.unit,
                tileset: StarCraftTilesetAssetSet.badlands,
                offset: 0,
                limit: 228,
                unitMetadataOnly: true,
              ),
            );
        expect(page.isSuccess, isTrue, reason: '${page.diagnostics}');
        expect(page.entries, hasLength(228));
        final commandCenter = page.entries[106].unitCapability!;
        expect(commandCenter.isBuilding, isTrue);
        expect(commandCenter.placementBox!.width, 128);
        expect(commandCenter.placementBox!.height, 96);
        var checked = 0;
        for (final entry in page.entries) {
          final capability = entry.unitCapability!;
          final box = capability.placementBox;
          if (box != null) {
            expect(capability.isBuilding, isTrue);
            expect(box.width % 32, 0);
            expect(box.height % 32, 0);
            checked++;
          }
        }
        expect(checked, greaterThan(1));
      },
      skip:
          !Platform.isWindows || realHelper == null || realInstallation == null,
    );

    for (final scenario in [
      'StarCraft',
      'building-box-old',
      'building-box-null',
      'building-box-version',
      'building-box-width',
      'building-box-height',
      'building-box-type',
      'building-box-nonbuilding',
    ]) {
      test(
        'validates optional versioned building placement box $scenario',
        () async {
          final page = await createGateway().list(
            requestFor(
              scenario,
              kind: StarCraftPlacementKind.unit,
              offset: 106,
              limit: 1,
            ),
          );
          final available = scenario == 'StarCraft';
          final legacy =
              scenario == 'building-box-old' || scenario == 'building-box-null';
          expect(
            page.isSuccess,
            available || legacy,
            reason: page.diagnostics.toString(),
          );
          if (page.isSuccess) {
            expect(page.entries.single.isPlaceable, isTrue);
            final box = page.entries.single.unitCapability!.placementBox;
            if (available) {
              expect(box!.width, 128);
              expect(box.height, 96);
            } else {
              expect(box, isNull);
            }
          } else {
            expect(
              page.diagnostics.single.code,
              StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
            );
          }
        },
        skip: !Platform.isWindows,
      );
    }

    test('clamps the final page and accepts an exhausted page', () async {
      final gateway = createGateway();
      final finalPage = await gateway.list(
        requestFor('StarCraft', operationId: 'final', offset: 258, limit: 8),
      );
      final exhausted = await gateway.list(
        requestFor('StarCraft', operationId: 'empty', offset: 300, limit: 8),
      );

      expect(finalPage.entries.map((entry) => entry.key.id), [258, 259]);
      expect(finalPage.nextOffset, isNull);
      expect(exhausted.isSuccess, isTrue);
      expect(exhausted.entries, isEmpty);
    }, skip: !Platform.isWindows);

    test(
      'isolates unavailable and relation-dependent Unit capabilities',
      () async {
        final gateway = createGateway();
        final first = await gateway.list(
          requestFor(
            'StarCraft',
            operationId: 'units-first',
            kind: StarCraftPlacementKind.unit,
          ),
        );
        final last = await gateway.list(
          requestFor(
            'StarCraft',
            operationId: 'units-last',
            kind: StarCraftPlacementKind.unit,
            offset: 226,
            limit: 4,
          ),
        );

        expect(first.totalEntries, 228);
        expect(first.entries.map((entry) => entry.key.id), [0, 1, 2]);
        expect(first.entries.every((entry) => entry.hasPreview), isTrue);
        expect(first.entries.first.isPlaceable, isTrue);
        expect(first.entries.first.unitCapability, isNotNull);
        expect(first.entries[1].isPlaceable, isFalse);
        expect(
          first.entries[1].issue?.code,
          'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE',
        );
        expect(first.entries[2].isPlaceable, isFalse);
        expect(
          first.entries[2].issue?.code,
          'SC_CATALOG_ITEM_UNIT_RELATION_REQUIRED',
        );
        expect(last.entries.map((entry) => entry.key.id), [226, 227]);
        expect(last.entries.first.hasPreview, isTrue);
        expect(
          last.entries.last.previewIssueCode,
          'SC_CASC_OBJECT_GRP_UNAVAILABLE',
        );
        expect(last.nextOffset, isNull);
      },
      skip: !Platform.isWindows,
    );

    test('lists all pure Sprites and isolates unavailable previews', () async {
      final page = await createGateway().list(
        requestFor(
          'StarCraft',
          operationId: 'sprites',
          kind: StarCraftPlacementKind.pureSprite,
          offset: 498,
          limit: 4,
        ),
      );

      expect(page.totalEntries, 517);
      expect(page.entries.map((entry) => entry.key.id), [498, 499, 500, 501]);
      expect(page.entries.take(2).every((entry) => entry.hasPreview), isTrue);
      expect(page.entries.skip(2).every((entry) => !entry.hasPreview), isTrue);
      expect(
        page.entries.last.issue?.code,
        'SC_CATALOG_ITEM_OBJECT_GRAPHIC_UNAVAILABLE',
      );
      expect(page.entries.last.displayName, 'Sprite #501');
    }, skip: !Platform.isWindows);

    test(
      'lists validated Doodad recipes and isolates an invalid entry',
      () async {
        final page = await createGateway().list(
          requestFor(
            'StarCraft',
            operationId: 'doodads',
            kind: StarCraftPlacementKind.doodad,
            limit: 4,
          ),
        );

        expect(page.isSuccess, isTrue, reason: page.diagnostics.toString());
        expect(page.totalEntries, 3);
        expect(page.entries.map((entry) => entry.key.id), [1, 2, 3]);
        final first = page.entries.first;
        expect(first.key.doodadStartTileGroup, 200);
        expect(first.isPlaceable, isTrue);
        expect(first.issue, isNull);
        expect(first.doodadRecipe!.width, 2);
        expect(first.doodadRecipe!.height, 2);
        expect(first.doodadRecipe!.hasRamp, isTrue);
        expect(first.doodadRecipe!.centerOffsetX, 32);
        expect(first.doodadRecipe!.centerOffsetY, 32);
        expect(first.doodadRecipe!.footprint.map((cell) => cell.rawTileValue), [
          3200,
          3201,
          3216,
          null,
        ]);
        expect(
          first.doodadRecipe!.footprint.map((cell) => cell.requiredTileGroup),
          [4, 0, 5, 6],
        );
        expect(first.doodadRecipe!.overlay!.id, 130);
        expect(first.doodadRecipe!.overlay!.thg2Flags, 0x1000);

        final invalid = page.entries[1];
        expect(invalid.doodadRecipe, isNull);
        expect(invalid.doodadRecipeIssueCode, 'SC_CASC_DOODAD_OVERLAY_INVALID');
        expect(invalid.issue?.code, 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID');
        final unitOverlay = page.entries[2].doodadRecipe!.overlay!;
        expect(unitOverlay.id, 100);
        expect(unitOverlay.thg2Flags, 0);
      },
      skip: !Platform.isWindows,
    );

    test('maps native storage and asset errors', () async {
      final gateway = createGateway();
      final storage = await gateway.list(
        requestFor('storage-error', operationId: 'storage'),
      );
      final asset = await gateway.list(
        requestFor('asset-error', operationId: 'asset'),
      );
      final missing = await gateway.list(
        requestFor('asset-missing', operationId: 'missing'),
      );
      final object = await gateway.list(
        requestFor(
          'object-metadata-error',
          operationId: 'object-metadata',
          kind: StarCraftPlacementKind.unit,
        ),
      );
      final doodad = await gateway.list(
        requestFor(
          'doodad-asset-error',
          operationId: 'doodad-assets',
          kind: StarCraftPlacementKind.doodad,
        ),
      );

      expect(
        storage.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.storageOpenFailed,
      );
      expect(
        asset.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.metadataInvalid,
      );
      expect(
        missing.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.metadataMissing,
      );
      expect(
        object.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.metadataInvalid,
      );
      expect(
        doodad.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.metadataInvalid,
      );
    }, skip: !Platform.isWindows);

    test('rejects mismatched and malformed responses', () async {
      for (final scenario in const [
        'invalid-response',
        'protocol-mismatch',
        'request-mismatch',
        'revision-mismatch',
        'path-mismatch',
        'catalog-page-mismatch',
        'catalog-entry-mismatch',
        'catalog-size-mismatch',
      ]) {
        final page = await createGateway().list(
          requestFor(scenario, operationId: 'bad-$scenario'),
        );
        expect(
          page.diagnostics.single.code,
          StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
          reason: scenario,
        );
      }
    }, skip: !Platform.isWindows);

    test('rejects malformed object preview availability', () async {
      for (final scenario in const [
        'catalog-preview-code-mismatch',
        'catalog-preview-field-missing',
        'catalog-total-mismatch',
        'catalog-read-count-mismatch',
      ]) {
        final page = await createGateway().list(
          requestFor(
            scenario,
            operationId: 'bad-$scenario',
            kind: StarCraftPlacementKind.pureSprite,
          ),
        );
        expect(
          page.diagnostics.single.code,
          StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
          reason: scenario,
        );
      }
    }, skip: !Platform.isWindows);

    test('rejects malformed Doodad recipe metadata', () async {
      for (final scenario in const [
        'catalog-recipe-code-mismatch',
        'catalog-recipe-field-missing',
        'catalog-recipe-center-mismatch',
        'catalog-recipe-value-mismatch',
        'catalog-read-count-mismatch',
      ]) {
        final page = await createGateway().list(
          requestFor(
            scenario,
            operationId: 'bad-doodad-$scenario',
            kind: StarCraftPlacementKind.doodad,
          ),
        );
        expect(
          page.diagnostics.single.code,
          StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
          reason: scenario,
        );
      }
    }, skip: !Platform.isWindows);

    test('rejects excessive output and terminates timeout', () async {
      final excessive = await createGateway(
        maximumProcessOutputBytes: 256,
      ).list(requestFor('large-output', operationId: 'large'));
      final timedOut = await createGateway(
        timeout: const Duration(milliseconds: 200),
      ).list(requestFor('hang', operationId: 'timeout'));

      expect(
        excessive.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.helperOutputLimitExceeded,
      );
      expect(
        timedOut.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.helperTimedOut,
      );
    }, skip: !Platform.isWindows);

    test('cancels the exact active operation', () async {
      final gateway = createGateway();
      final future = gateway.list(
        requestFor('hang', operationId: 'cancel-this'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await gateway.cancel('cancel-this');

      final page = await future;
      expect(
        page.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.helperCancelled,
      );
    }, skip: !Platform.isWindows);

    test('rejects a relative installation without starting helper', () async {
      final request = StarCraftPlacementCatalogRequest(
        operationId: 'relative',
        installationPath: 'relative/StarCraft',
        kind: StarCraftPlacementKind.tile,
        tileset: StarCraftTilesetAssetSet.badlands,
      );

      final page = await createGateway().list(request);
      expect(
        page.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.installationPathInvalid,
      );
    }, skip: !Platform.isWindows);
    test(
      'unit-sprite catalog reuses validated Unit metadata with distinct keys',
      () async {
        final request = requestFor(
          'StarCraft',
          kind: StarCraftPlacementKind.spriteUnit,
        );
        final page = await createGateway().list(request);
        expect(page.isSuccess, isTrue, reason: '${page.diagnostics}');
        expect(page.request, same(request));
        expect(page.totalEntries, 228);
        expect(page.entries.map((e) => e.key.stableId), [
          'spriteUnit:0',
          'spriteUnit:1',
          'spriteUnit:2',
        ]);
        expect(page.entries.first.unitCapability!.unitId, 0);
        expect(page.entries.first.isPlaceable, isTrue);
        expect(
          page.entries[1].issue!.code,
          'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE',
        );
        expect(
          page.entries[2].issue!.code,
          'SC_CATALOG_ITEM_UNIT_RELATION_REQUIRED',
        );
        expect(
          page.helperVersion,
          ProcessStarCraftPlacementCatalogGateway.helperVersion,
        );
        final tail = await createGateway().list(
          requestFor(
            'StarCraft',
            kind: StarCraftPlacementKind.spriteUnit,
            offset: 226,
            limit: 4,
          ),
        );
        expect(tail.entries.map((e) => e.key.id), [226, 227]);
        expect(
          tail.entries.last.previewIssueCode,
          'SC_CASC_OBJECT_GRP_UNAVAILABLE',
        );
        expect(tail.nextOffset, isNull);
      },
      skip: !Platform.isWindows,
    );

    test(
      'unit-sprite adaptation preserves rejected metadata responses',
      () async {
        final request = requestFor(
          'catalog-page-mismatch',
          kind: StarCraftPlacementKind.spriteUnit,
        );
        final page = await createGateway().list(request);
        expect(page.isSuccess, isFalse);
        expect(page.request, same(request));
        expect(page.entries, isEmpty);
        expect(page.diagnostics, isNotEmpty);
      },
      skip: !Platform.isWindows,
    );
  });
}

Future<String> _findPowerShellExecutable() async {
  for (final candidate in const [
    r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
    r'C:\Program Files\PowerShell\7\pwsh.exe',
  ]) {
    if (await File(candidate).exists()) {
      return candidate;
    }
  }
  throw StateError('PowerShell is required for helper process tests.');
}
