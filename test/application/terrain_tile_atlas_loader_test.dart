import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_tile_atlas_loader.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';

void main() {
  test(
    'creates a sorted unique MTXM context and separates unsupported values',
    () {
      final views = _decodeViews([0x4000, 2, 1, 2, 0xffff, 0]);
      final inspection = _inspection();
      final loader = TerrainTileAtlasLoader(gateway: _FakeGateway(_renderAll));

      final context = loader.createContext(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(inspection),
      )!;

      expect(context.renderableRawValues, [0, 1, 2]);
      expect(context.unsupportedRawValues, [0x4000, 0xffff]);
      expect(context.identity.installationPath, r'C:\Games\StarCraft');
      expect(context.identity.storageProduct, 's1');
      expect(context.identity.storageBuildNumber, 13515);
      expect(context.identity.helperVersion, '0.3.0');
      expect(context.identity.cascLibRevision, 'pinned-casc');
      expect(context.identity.tileset, StarCraftTilesetAssetSet.jungle);

      final sameSnapshot = loader.createContext(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(inspection),
      )!;
      final refreshedSnapshot = loader.createContext(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(_inspection()),
      )!;
      expect(sameSnapshot.identity, context.identity);
      expect(refreshedSnapshot.identity, isNot(context.identity));
    },
  );

  test('extracts each 32x32 tile from a multi-column RGBA atlas', () async {
    final views = _decodeViews([0, 1, 2]);
    final requests = <StarCraftTileAtlasRequest>[];
    final loader = TerrainTileAtlasLoader(
      gateway: _FakeGateway((request) async {
        requests.add(request);
        return StarCraftTileAtlasResult(
          request: request,
          tileSize: 32,
          columns: 2,
          rows: 2,
          rawValues: request.rawValues,
          rgbaBytes: _solidAtlas(
            columns: 2,
            rows: 2,
            cellValues: const [11, 22, 33, 99],
          ),
          unsupportedRawValues: const [],
          storageProduct: 's1',
          storageBuildNumber: 13515,
          helperVersion: '0.3.0',
          cascLibRevision: 'pinned-casc',
        );
      }),
    );
    final context = loader.createContext(
      metadataViews: views.metadata,
      terrainViews: views.terrain,
      assetState: _readyState(_inspection()),
    )!;

    final result = await loader.loadBatch(
      context: context,
      rawValues: const [0, 1, 2],
    );

    expect(requests, hasLength(1));
    expect(requests.single.rawValues, [0, 1, 2]);
    expect(result.diagnostics, isEmpty);
    expect(result.unsupportedRawValues, isEmpty);
    expect(result.rgbaTiles.keys, [0, 1, 2]);
    expect(result.rgbaTiles[0], everyElement(11));
    expect(result.rgbaTiles[1], everyElement(22));
    expect(result.rgbaTiles[2], everyElement(33));
    expect(result.rgbaTiles[0], hasLength(32 * 32 * 4));
  });

  test('preserves helper unsupported values and diagnostics', () async {
    final views = _decodeViews([0, 1, 2]);
    final loader = TerrainTileAtlasLoader(
      gateway: _FakeGateway((request) async {
        return StarCraftTileAtlasResult(
          request: request,
          tileSize: 32,
          columns: 2,
          rows: 1,
          rawValues: const [0, 2],
          rgbaBytes: _solidAtlas(columns: 2, rows: 1, cellValues: const [7, 9]),
          unsupportedRawValues: const [1],
          storageProduct: 's1',
          storageBuildNumber: 13515,
          helperVersion: '0.3.0',
          cascLibRevision: 'pinned-casc',
        );
      }),
    );
    final context = loader.createContext(
      metadataViews: views.metadata,
      terrainViews: views.terrain,
      assetState: _readyState(_inspection()),
    )!;

    final result = await loader.loadBatch(
      context: context,
      rawValues: const [0, 1, 2],
    );

    expect(result.rgbaTiles.keys, [0, 2]);
    expect(result.unsupportedRawValues, [1]);
  });

  test(
    'returns stable diagnostics for gateway failure and mismatched result',
    () async {
      final views = _decodeViews([0]);
      final state = _readyState(_inspection());
      final failingLoader = TerrainTileAtlasLoader(
        gateway: _FakeGateway((_) => throw StateError('gateway exploded')),
      );
      final context = failingLoader.createContext(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: state,
      )!;

      final failed = await failingLoader.loadBatch(
        context: context,
        rawValues: const [0],
      );
      expect(failed.rgbaTiles, isEmpty);
      expect(failed.unsupportedRawValues, [0]);
      expect(
        failed.diagnostics.single.code,
        TerrainTileAtlasDiagnosticCodes.gatewayFailed,
      );
      expect(
        failed.diagnostics.single.rawDetails,
        contains('gateway exploded'),
      );

      final mismatchLoader = TerrainTileAtlasLoader(
        gateway: _FakeGateway((request) async {
          final mismatchedRequest = StarCraftTileAtlasRequest(
            installationPath: r'D:\Other\StarCraft',
            tileset: request.tileset,
            rawValues: request.rawValues,
          );
          return StarCraftTileAtlasResult(
            request: mismatchedRequest,
            tileSize: 32,
            columns: 1,
            rows: 1,
            rawValues: request.rawValues,
            rgbaBytes: Uint8List(32 * 32 * 4),
            unsupportedRawValues: const [],
            storageProduct: 's1',
            storageBuildNumber: 13515,
            helperVersion: '0.3.0',
            cascLibRevision: 'pinned-casc',
          );
        }),
      );
      final mismatched = await mismatchLoader.loadBatch(
        context: context,
        rawValues: const [0],
      );
      expect(
        mismatched.diagnostics.single.code,
        TerrainTileAtlasDiagnosticCodes.resultMismatch,
      );
      expect(mismatched.unsupportedRawValues, [0]);
    },
  );

  test(
    'rejects unavailable contexts and invalid batches before the gateway',
    () async {
      final views = _decodeViews([0, 1]);
      var calls = 0;
      final loader = TerrainTileAtlasLoader(
        gateway: _FakeGateway((request) {
          calls++;
          return _renderAll(request);
        }),
      );
      expect(
        loader.createContext(
          metadataViews: views.metadata,
          terrainViews: views.terrain,
          assetState: StarCraftDataAssetSettingsState(
            status: StarCraftDataAssetSettingsStatus.unavailable,
          ),
        ),
        isNull,
      );

      final context = loader.createContext(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(_inspection()),
      )!;
      expect(
        () => loader.loadBatch(context: context, rawValues: const []),
        throwsRangeError,
      );
      expect(
        () => loader.loadBatch(context: context, rawValues: const [1, 0]),
        throwsArgumentError,
      );
      expect(
        () => loader.loadBatch(context: context, rawValues: const [2]),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );
}

Future<StarCraftTileAtlasResult> _renderAll(
  StarCraftTileAtlasRequest request,
) async {
  return StarCraftTileAtlasResult(
    request: request,
    tileSize: 32,
    columns: request.rawValues.length,
    rows: 1,
    rawValues: request.rawValues,
    rgbaBytes: Uint8List(request.rawValues.length * 32 * 32 * 4),
    unsupportedRawValues: const [],
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.3.0',
    cascLibRevision: 'pinned-casc',
  );
}

({ChkMetadataViews metadata, ChkTerrainViews terrain}) _decodeViews(
  List<int> rawValues,
) {
  final mtxm = Uint8List(rawValues.length * 2);
  final mtxmData = ByteData.sublistView(mtxm);
  for (var index = 0; index < rawValues.length; index++) {
    mtxmData.setUint16(index * 2, rawValues[index], Endian.little);
  }
  final document = _documentFromSections([
    _section('DIM ', [rawValues.length, 0, 1, 0]),
    _section('ERA ', [4, 0]),
    _section('MTXM', mtxm),
  ]);
  return (
    metadata: const ChkMetadataViewDecoder().decode(document),
    terrain: const ChkTerrainViewDecoder().decode(document),
  );
}

StarCraftDataAssetSettingsState _readyState(
  StarCraftDataAssetInspection inspection,
) {
  return StarCraftDataAssetSettingsState(
    status: StarCraftDataAssetSettingsStatus.ready,
    configuredPath: inspection.installationPath,
    inspection: inspection,
  );
}

StarCraftDataAssetInspection _inspection() {
  return StarCraftDataAssetInspection(
    installationPath: r'C:\Games\StarCraft',
    requiredAssetCount: StarCraftDataAssetManifest.requiredTilesetAssets.length,
    foundAssetCount: StarCraftDataAssetManifest.requiredTilesetAssets.length,
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.3.0',
    cascLibRevision: 'pinned-casc',
    totalAssetBytes: 1234,
  );
}

Uint8List _solidAtlas({
  required int columns,
  required int rows,
  required List<int> cellValues,
}) {
  final pixels = Uint8List(columns * rows * 32 * 32 * 4);
  final atlasWidth = columns * 32;
  for (var cell = 0; cell < cellValues.length; cell++) {
    final cellX = (cell % columns) * 32;
    final cellY = (cell ~/ columns) * 32;
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 32; x++) {
        final pixelOffset = ((cellY + y) * atlasWidth + cellX + x) * 4;
        pixels.fillRange(pixelOffset, pixelOffset + 4, cellValues[cell]);
      }
    }
  }
  return pixels;
}

RawChkDocument _documentFromSections(List<RawChkSection> sections) {
  var sourceOffset = 0;
  final positioned = <RawChkSection>[];
  for (final section in sections) {
    positioned.add(
      RawChkSection(
        nameBytes: section.nameBytes,
        declaredLength: section.declaredLength,
        payload: section.payload,
        sourceOffset: sourceOffset,
      ),
    );
    sourceOffset += RawChkParser.headerLength + section.declaredLength;
  }
  return RawChkDocument(sections: positioned, sourceLength: sourceOffset);
}

RawChkSection _section(String name, List<int> payload) {
  return RawChkSection(
    nameBytes: name.codeUnits,
    declaredLength: payload.length,
    payload: payload,
    sourceOffset: 0,
  );
}

final class _FakeGateway implements StarCraftTileAtlasGateway {
  const _FakeGateway(this.handler);

  final Future<StarCraftTileAtlasResult> Function(
    StarCraftTileAtlasRequest request,
  )
  handler;

  @override
  Future<StarCraftTileAtlasResult> render(StarCraftTileAtlasRequest request) {
    return handler(request);
  }
}
