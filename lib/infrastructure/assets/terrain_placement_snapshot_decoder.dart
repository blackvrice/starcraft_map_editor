import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../application/ports/terrain_connection_snapshot_gateway.dart';
import '../../application/ports/terrain_placement_snapshot_gateway.dart';
import '../../domain/placement/terrain_placement_snapshot.dart';
import 'starcraft_data_helper_protocol.dart';

final class TerrainPlacementSnapshotDecoder {
  const TerrainPlacementSnapshotDecoder();

  TerrainPlacementSource decode(
    Map<String, dynamic> json, {
    required String operationId,
    required String installationPath,
    required int tileset,
  }) {
    if (tileset < 0 ||
        tileset > 7 ||
        json['protocolVersion'] is! int ||
        json['protocolVersion'] != StarCraftDataHelperProtocol.version ||
        json['helperVersion'] != StarCraftDataHelperProtocol.helperVersion ||
        json['cascLibRevision'] !=
            StarCraftDataHelperProtocol.cascLibRevision ||
        json['requestId'] != operationId ||
        json['operation'] != 'readTerrainPlacement' ||
        json['status'] != 'success' ||
        json['snapshotVersion'] is! int ||
        json['snapshotVersion'] != TerrainPlacementSnapshot.version ||
        json['tileset'] is! int ||
        json['tileset'] != tileset) {
      throw const FormatException('Terrain placement identity mismatch.');
    }
    final install = _object(json['installation']);
    final product = install['storageProduct'];
    if (install['path'] is! String ||
        (install['path'] as String).toLowerCase() !=
            installationPath.toLowerCase() ||
        product is! String ||
        product.isEmpty ||
        product.length > 128 ||
        product.codeUnits.any((v) => v < 32 || (v >= 127 && v <= 159))) {
      throw const FormatException('Invalid terrain placement installation.');
    }
    final build = _int(install['storageBuildNumber'], 0xffffffff);
    const names = [
      'badlands',
      'platform',
      'install',
      'ashworld',
      'jungle',
      'desert',
      'ice',
      'twilight',
    ];
    const extensions = ['cv5', 'vf4'];
    final rawAssets = _list(json['assets'], 2);
    final assets = <TerrainSnapshotAsset>[];
    for (var i = 0; i < 2; i++) {
      final asset = _object(rawAssets[i]);
      final path = 'tileset\\${names[tileset]}.${extensions[i]}';
      final stride = i == 0 ? 52 : 32;
      final countLimit = i == 0 ? 4096 : 65536;
      final bytes = _int(asset['bytes'], stride * countLimit);
      final hash = asset['sha256'];
      if (asset['path'] != path ||
          bytes == 0 ||
          bytes % stride != 0 ||
          hash is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        throw const FormatException('Invalid CV5/VF4 asset manifest.');
      }
      assets.add(TerrainSnapshotAsset(path, bytes, hash));
    }
    final groups = assets[0].byteLength ~/ 52;
    final rawBuildable = _list(json['groupBuildable'], groups);
    if (rawBuildable.any((value) => value is! bool)) {
      throw const FormatException('Buildability must be boolean.');
    }
    final buildable = rawBuildable.cast<bool>();
    final references = _list(json['megaTileReferences'], groups)
        .map((row) => _list(row, 16).map((id) => _int(id, 65535)).toList())
        .toList();
    final masks = _list(
      json['walkableMasks'],
      assets[1].byteLength ~/ 32,
    ).map((mask) => _int(mask, 65535)).toList();
    final snapshot = TerrainPlacementSnapshot(
      tileset: tileset,
      groupBuildable: buildable,
      megaTileReferences: references,
      walkableMasks: masks,
    );
    // Canonical identity excludes request IDs and installation directory.
    final identity = [
      1,
      StarCraftDataHelperProtocol.helperVersion,
      StarCraftDataHelperProtocol.cascLibRevision,
      tileset,
      product,
      build,
      for (final asset in assets) [asset.path, asset.byteLength, asset.sha256],
      buildable,
      references,
      masks,
    ];
    return TerrainPlacementSource(
      snapshot: snapshot,
      revision:
          'terrain-placement-v1:${sha256.convert(utf8.encode(jsonEncode(identity)))}',
      helperVersion: StarCraftDataHelperProtocol.helperVersion,
      cascLibRevision: StarCraftDataHelperProtocol.cascLibRevision,
      storageProduct: product,
      storageBuildNumber: build,
      assets: assets,
    );
  }

  Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected object.');
    }
    return value;
  }

  List<dynamic> _list(Object? value, int count) {
    if (value is! List || value.length != count) {
      throw const FormatException('Invalid list coverage.');
    }
    return value;
  }

  int _int(Object? value, int max) {
    if (value is! int || value < 0 || value > max) {
      throw const FormatException('Invalid integer.');
    }
    return value;
  }
}
