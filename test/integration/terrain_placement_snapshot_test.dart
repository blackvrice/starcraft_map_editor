import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/terrain_placement_snapshot.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';

void main() {
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  final installation = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  test(
    'all eight local CV5/VF4 snapshots match existing CV5 identities and are read-only',
    () async {
      final gateway = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper!,
      );
      for (var tileset = 0; tileset < 8; tileset++) {
        final result = await gateway.readPlacement(
          operationId: 'placement-$tileset',
          installationPath: installation!,
          tileset: tileset,
        );
        expect(
          result.isSuccess,
          isTrue,
          reason: '${result.errorCode}: ${result.stderr}',
        );
        final source = result.source!;
        final snapshot = source.snapshot;
        expect(source.assets, hasLength(2));
        expect(source.assets.last.path, endsWith('.vf4'));
        expect(
          snapshot.groupBuildable.length,
          source.assets.first.byteLength ~/ 52,
        );
        expect(
          snapshot.walkableMasks.length,
          source.assets.last.byteLength ~/ 32,
        );
        final connections = await gateway.read(
          operationId: 'connections-$tileset',
          installationPath: installation,
          tileset: tileset,
        );
        expect(connections.isSuccess, isTrue, reason: connections.errorCode);
        expect(
          source.assets.first.sha256,
          connections.snapshot!.assets.first.sha256,
        );
        for (final group in connections.snapshot!.groups) {
          expect(
            snapshot.groupBuildable[group.group],
            (group.flagsWord & 0x80) == 0,
          );
          expect(
            snapshot.megaTileReferences[group.group],
            group.megaTileReferences,
          );
        }
        final repeated = await gateway.readPlacement(
          operationId: 'repeat-$tileset',
          installationPath: installation,
          tileset: tileset,
        );
        expect(repeated.isSuccess, isTrue, reason: repeated.errorCode);
        expect(repeated.source!.revision, source.revision);

        // Exercise real derived facts with a self-authored one-tile CHK only.
        var checked = false;
        for (var raw = 0; raw < snapshot.groupBuildable.length * 16; raw++) {
          final facts = snapshot.tile(raw);
          if (facts == null) continue;
          final dim = Uint8List(12)..setRange(0, 4, 'DIM '.codeUnits);
          ByteData.sublistView(dim)
            ..setUint32(4, 4, Endian.little)
            ..setUint16(8, 1, Endian.little)
            ..setUint16(10, 1, Endian.little);
          final tiles = Uint8List(10)..setRange(0, 4, 'MTXM'.codeUnits);
          ByteData.sublistView(tiles)
            ..setUint32(4, 2, Endian.little)
            ..setUint16(8, raw, Endian.little);
          final original = Uint8List.fromList([...dim, ...tiles]);
          final document = const RawChkParser().parse(original).document!;
          final terrain = const ChkTerrainViewDecoder()
              .decode(document)
              .tileMaps
              .single;
          final bounds = UnitCollisionProfile(
            left: 0,
            up: 0,
            right: 0,
            down: 0,
            isFlyer: false,
          ).boundsAt(0, 0);
          expect(
            snapshot.check(
              terrain: terrain,
              mapTileset: tileset,
              bounds: bounds,
              requireBuildable: false,
            ),
            facts.walkableMask & 1 == 1
                ? TerrainFootprintCheck.clear
                : TerrainFootprintCheck.unwalkable,
          );
          expect(
            snapshot.check(
              terrain: terrain,
              mapTileset: tileset,
              bounds: bounds,
              requireBuildable: true,
            ),
            !facts.buildable
                ? TerrainFootprintCheck.unbuildable
                : facts.walkableMask & 1 == 1
                ? TerrainFootprintCheck.clear
                : TerrainFootprintCheck.unwalkable,
          );
          expect(const RawChkEncoder().encode(document), original);
          checked = true;
          break;
        }
        expect(checked, isTrue);
      }
    },
    skip: !Platform.isWindows || helper == null || installation == null,
  );
}
