import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  final unit = _key(StarCraftObjectGraphicKind.unit, 7, playerColor: 0);
  final neutralUnit = _key(StarCraftObjectGraphicKind.unit, 7);
  final sprite = _key(StarCraftObjectGraphicKind.sprite, 11);

  test('request requires a safe ID and sorted unique bounded object keys', () {
    expect(
      () => StarCraftObjectAtlasRequest(
        operationId: 'object-atlas-1',
        installationPath: r'C:\Games\StarCraft',
        tileset: StarCraftTilesetAssetSet.jungle,
        objects: [unit, neutralUnit, sprite],
      ),
      returnsNormally,
    );
    for (final objects in [
      <StarCraftObjectGraphicKey>[],
      [unit, unit],
      [sprite, unit],
      List<StarCraftObjectGraphicKey>.generate(
        257,
        (index) => _key(StarCraftObjectGraphicKind.unit, index),
      ),
    ]) {
      expect(
        () => StarCraftObjectAtlasRequest(
          operationId: 'object-atlas-1',
          installationPath: r'C:\Games\StarCraft',
          tileset: StarCraftTilesetAssetSet.jungle,
          objects: objects,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => StarCraftObjectAtlasRequest(
        operationId: 'unsafe id',
        installationPath: r'C:\Games\StarCraft',
        tileset: StarCraftTilesetAssetSet.jungle,
        objects: [unit],
      ),
      throwsArgumentError,
    );
  });

  test(
    'result copies pixels and requires exact rendered fallback coverage',
    () {
      final request = _request([unit, sprite]);
      final sourcePixels = Uint8List(2 * 3 * 4)..[0] = 91;
      final entry = StarCraftObjectAtlasEntry(
        key: unit,
        spriteId: 11,
        imageId: 42,
        width: 2,
        height: 3,
        anchorX: 1,
        anchorY: 2,
        frameIndex: 0,
        rgbaBytes: sourcePixels,
      );
      final result = StarCraftObjectAtlasResult(
        request: request,
        entries: [entry],
        unsupportedObjects: [
          StarCraftUnsupportedObjectGraphic(
            key: sprite,
            code: 'SC_CASC_OBJECT_GRP_MISSING',
          ),
        ],
        storageProduct: 's1',
        storageBuildNumber: 13515,
        helperVersion: '0.4.0',
        cascLibRevision: 'pinned-casc',
        totalAssetBytes: sourcePixels.length,
      );

      sourcePixels[0] = 0;
      expect(result.isSuccess, isTrue);
      expect(result.entries.single.rgbaBytes[0], 91);
      expect(result.unsupportedObjects.single.key, sprite);
      expect(
        () => result.entries.single.rgbaBytes[0] = 1,
        throwsUnsupportedError,
      );

      expect(
        () => StarCraftObjectAtlasResult(
          request: request,
          entries: [entry],
          unsupportedObjects: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => StarCraftObjectAtlasResult(
          request: request,
          entries: [entry],
          unsupportedObjects: [
            StarCraftUnsupportedObjectGraphic(
              key: unit,
              code: 'SC_CASC_OBJECT_GRP_MISSING',
            ),
            StarCraftUnsupportedObjectGraphic(
              key: sprite,
              code: 'SC_CASC_OBJECT_GRP_MISSING',
            ),
          ],
        ),
        throwsArgumentError,
      );
    },
  );

  test('failed result preserves the request as marker fallback', () {
    final request = _request([unit, sprite]);
    final result = StarCraftObjectAtlasResult.failed(
      request: request,
      diagnostic: const EditorDiagnostic(
        code: 'SC_CASC_OBJECT_RENDER_FAILED',
        message: 'failed',
        severity: DiagnosticSeverity.warning,
        stage: DiagnosticStage.validate,
      ),
    );

    expect(result.isSuccess, isFalse);
    expect(result.entries, isEmpty);
    expect(
      result.unsupportedObjects.map((unsupported) => unsupported.key),
      request.objects,
    );
  });
}

StarCraftObjectGraphicKey _key(
  StarCraftObjectGraphicKind kind,
  int id, {
  int? playerColor,
}) {
  return StarCraftObjectGraphicKey(
    kind: kind,
    id: id,
    playerColor: playerColor,
  );
}

StarCraftObjectAtlasRequest _request(List<StarCraftObjectGraphicKey> objects) {
  return StarCraftObjectAtlasRequest(
    operationId: 'object-atlas-test',
    installationPath: r'C:\Games\StarCraft',
    tileset: StarCraftTilesetAssetSet.jungle,
    objects: objects,
  );
}
