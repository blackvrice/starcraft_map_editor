import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/preplaced_unit_power_layout.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';
import 'package:starcraft_map_editor/domain/placement/unit_power_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_range_projection.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_eud_dat_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import '../fixtures/basic_editing_fixture.dart';

void main() {
  final path = Platform.environment['STARCRAFT_TEST_INSTALLATION'],
      helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  test(
    'reads local fixed DAT defaults and complete references with source hashes',
    () async {
      final result = await ProcessEudDatGateway(
        helperExecutablePath: helper!,
      ).read(operationId: 'eud-real', installationPath: path!);
      expect(
        result.isSuccess,
        isTrue,
        reason: '${result.errorCode}\n${result.stderr}',
      );
      final data = result.source!;
      expect(data.hashes, hasLength(7));
      expect(data.snapshot.columns, hasLength(68));
      expect(data.snapshot.raw('unit.hitpoints', 0), greaterThan(0));
      expect(data.snapshot.raw('unit.minerals', 0), greaterThan(0));
      expect(data.snapshot.raw('unit.buildTime', 0), greaterThan(0));
      expect(data.snapshot.raw('weapon.baseDamage', 0), greaterThan(0));
      expect(data.snapshot.raw('weapon.bonusDamage', 0), isA<int>());
      expect(data.snapshot.weaponIndex().units, hasLength(228));
      expect(data.snapshot.graph().unresolved, isEmpty);
      expect(data.snapshot.value('weapon.cooldown', 0), isA<int>());
      expect(data.snapshot.value('player.terranSupplyMax', 0), isNull);
      expect(result.stdout, contains('"sha256"'));
      expect(data.build, greaterThan(0));
      final units = const ChkObjectViewDecoder()
          .decode(
            basicDocument(units: [basicUnit(type: 3), basicUnit(type: 5)]),
          )
          .unitSections
          .single
          .units;
      final ranges = UnitRangeProjection.fromDat(
        dat: data.snapshot,
        selected: units,
        mapWidth: 32,
        mapHeight: 32,
      );
      expect(ranges.unknownUnits, 0);
      expect(ranges.selectionLimitExceeded, isFalse);
      expect(
        ranges.rings.where((r) => r.kind == UnitRangeKind.sight).length,
        2,
      );
      for (final id in [3, 5]) {
        final links = data.snapshot.weaponIndex().weaponLinks(id);
        expect(links, isNotEmpty);
        expect(links.any((link) => link.unit != id), isTrue);
        for (final link in links) {
          expect(
            ranges.rings.any(
              (r) =>
                  r.sourceUnit == link.unit &&
                  r.weapon == link.weapon &&
                  r.maximum ==
                      data.snapshot.raw('weapon.maxRange', link.weapon),
            ),
            isTrue,
          );
        }
      }
      final page =
          await ProcessStarCraftPlacementCatalogGateway(
            helperExecutablePath: helper,
          ).list(
            StarCraftPlacementCatalogRequest(
              operationId: 'overlay-real-power',
              installationPath: path,
              kind: StarCraftPlacementKind.unit,
              tileset: StarCraftTilesetAssetSet.badlands,
              limit: 228,
              unitMetadataOnly: true,
            ),
          );
      expect(page.isSuccess, isTrue);
      expect(
        (page.storageProduct, page.storageBuildNumber, page.helperVersion),
        (data.product, data.build, data.helperVersion),
      );
      final pylon = basicUnit(type: 156, x: 512, y: 512);
      ByteData.sublistView(pylon).setUint16(14, 1, Endian.little);
      final providers = const ChkObjectViewDecoder()
          .decode(basicDocument(units: [pylon]))
          .unitSections
          .single
          .units;
      final capabilities = <int, UnitPlacementCapability>{
        for (final entry in page.entries)
          if (entry.unitCapability != null) entry.key.id: entry.unitCapability!,
      };
      final power = UnitPowerCatalog(capabilities).project(
        owner: 0,
        mapWidthTiles: 32,
        mapHeightTiles: 32,
        existing: PreplacedUnitPowerLayout.project(providers),
      );
      expect(power.failure, isNull);
      expect(power.containsPoint(512, 512), isTrue);
      expect(power.containsPoint(100, 100), isFalse);
    },
    skip: path == null || helper == null
        ? 'Set STARCRAFT_TEST_INSTALLATION and STARCRAFT_DATA_HELPER_PATH.'
        : false,
  );
}
