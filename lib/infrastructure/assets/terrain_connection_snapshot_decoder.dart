import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../application/ports/terrain_connection_snapshot_gateway.dart';
import 'starcraft_data_helper_protocol.dart';

/// Strict wire validation. No normalization of unknown CV5 words or shapes.
class TerrainConnectionSnapshotDecoder {
  const TerrainConnectionSnapshotDecoder();

  TerrainConnectionSnapshot decode(
    Map<String, dynamic> json, {
    required String operationId,
    required String installationPath,
    required int tileset,
  }) {
    if (json['protocolVersion'] is! int ||
        json['snapshotVersion'] is! int ||
        json['tileset'] is! int ||
        json['protocolVersion'] != StarCraftDataHelperProtocol.version ||
        json['helperVersion'] != StarCraftDataHelperProtocol.helperVersion ||
        json['cascLibRevision'] !=
            StarCraftDataHelperProtocol.cascLibRevision ||
        json['requestId'] != operationId ||
        json['operation'] != 'readTerrainConnections' ||
        json['status'] != 'success' ||
        json['snapshotVersion'] != 2 ||
        json['tileset'] != tileset ||
        json['isomShapesResolved'] != false ||
        tileset < 0 ||
        tileset > 7) {
      throw const FormatException('Terrain snapshot identity mismatch.');
    }
    final install = _object(json['installation']);
    if (install['path'] is! String ||
        (install['path'] as String).toLowerCase() !=
            installationPath.toLowerCase()) {
      throw const FormatException('Terrain installation mismatch.');
    }
    final product = install['storageProduct'];
    if (product is! String || product.isEmpty || product.length > 128) {
      throw const FormatException('Invalid storage product.');
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
    const extensions = ['cv5', 'vx4ex', 'vr4', 'wpe'];
    final rawAssets = _list(json['assets'], 4);
    final assets = <TerrainSnapshotAsset>[];
    var total = 0;
    for (var i = 0; i < 4; i++) {
      final a = _object(rawAssets[i]);
      final path = 'tileset\\${names[tileset]}.${extensions[i]}';
      final length = _int(a['bytes'], 256 * 1024 * 1024);
      final hash = a['sha256'];
      if (a['path'] != path ||
          length == 0 ||
          hash is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
          (i == 0 && (length % 52 != 0 || length ~/ 52 > 4096)) ||
          ((i == 1 || i == 2) && length % 64 != 0) ||
          (i == 3 && length != 1024)) {
        throw const FormatException('Invalid terrain asset manifest.');
      }
      total += length;
      assets.add(TerrainSnapshotAsset(path, length, hash));
    }
    if (total > 256 * 1024 * 1024) {
      throw const FormatException('Terrain assets exceed limit.');
    }
    final rawGroups = _list(json['groups'], assets.first.byteLength ~/ 52);
    final groups = <TerrainSnapshotGroup>[];
    for (var i = 0; i < rawGroups.length; i++) {
      final g = _object(rawGroups[i]);
      if (g['group'] is! int || g['group'] != i) {
        throw const FormatException('Terrain group coverage mismatch.');
      }
      final members = g['renderableMembers'];
      if (members is! List || members.length > 16) {
        throw const FormatException('Invalid terrain members.');
      }
      final ids = members.map((m) => _int(m, 15)).toList();
      for (var j = 1; j < ids.length; j++) {
        if (ids[j] <= ids[j - 1]) {
          throw const FormatException(
            'Terrain members must be ordered and unique.',
          );
        }
      }
      groups.add(
        TerrainSnapshotGroup(
          group: i,
          terrainTypeWord: _int(g['terrainTypeWord'], 65535),
          flagsWord: _int(g['flagsWord'], 65535),
          linkWords: _list(
            g['linkWords'],
            4,
          ).map((v) => _int(v, 65535)).toList(),
          stackWords: _list(
            g['stackWords'],
            4,
          ).map((v) => _int(v, 65535)).toList(),
          megaTileReferences: _list(
            g['megaTileReferences'],
            16,
          ).map((v) => _int(v, 65535)).toList(),
          renderableMembers: ids,
        ),
      );
    }
    // Canonical field order excludes transport IDs and installation location.
    final identity = [
      2,
      StarCraftDataHelperProtocol.helperVersion,
      StarCraftDataHelperProtocol.cascLibRevision,
      tileset,
      product,
      build,
      for (final a in assets) [a.path, a.byteLength, a.sha256],
      for (final g in groups)
        [
          g.group,
          g.terrainTypeWord,
          g.flagsWord,
          g.linkWords,
          g.stackWords,
          g.megaTileReferences,
          g.renderableMembers,
        ],
    ];
    return TerrainConnectionSnapshot(
      tileset: tileset,
      revision:
          'terrain-snapshot-v2:${sha256.convert(utf8.encode(jsonEncode(identity)))}',
      helperVersion: StarCraftDataHelperProtocol.helperVersion,
      storageProduct: product,
      storageBuildNumber: build,
      assets: assets,
      groups: groups,
    );
  }

  Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected object.');
    }
    return value;
  }

  List<dynamic> _list(Object? value, int length) {
    if (value is! List || value.length != length) {
      throw const FormatException('Invalid list length.');
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
