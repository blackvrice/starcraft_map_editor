import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/objects/object_sprite_atlas_loader.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_document.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_parser.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_section.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_metadata_views.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_object_views.dart';

void main() {
  test('creates sorted unique unit and THG2 sprite keys from map views', () {
    final views = _views();
    final inspection = _inspection();
    final loader = ObjectSpriteAtlasLoader(gateway: _FakeGateway());

    final context = loader.createContext(
      metadataViews: views.metadata,
      objectViews: views.objects,
      assetState: _readyState(inspection),
    );

    expect(context, isNotNull);
    expect(context!.identity.tileset, StarCraftTilesetAssetSet.jungle);
    expect(context.identity.inspectionSnapshot, same(inspection));
    expect(context.objectKeys, [
      _key(StarCraftObjectGraphicKind.unit, 5, playerColor: 0),
      _key(StarCraftObjectGraphicKind.unit, 7, playerColor: 1),
      _key(StarCraftObjectGraphicKind.sprite, 8),
    ]);
  });

  test('loads a matching batch and forwards cancellation', () async {
    final gateway = _FakeGateway(unsupportedIds: const {8});
    final loader = ObjectSpriteAtlasLoader(gateway: gateway);
    final context = loader.createContext(
      metadataViews: _views().metadata,
      objectViews: _views().objects,
      assetState: _readyState(_inspection()),
    )!;

    final result = await loader.loadBatch(
      context: context,
      operationId: 'object-atlas-1',
      objectKeys: context.objectKeys,
    );
    await loader.cancel('object-atlas-1');

    expect(result.isSuccess, isTrue);
    expect(result.frames.keys, context.objectKeys.take(2));
    expect(result.frames.values.first.rgbaBytes, hasLength(2 * 3 * 4));
    expect(result.unsupportedObjects.single.key.id, 8);
    expect(gateway.cancelled, ['object-atlas-1']);
  });

  test(
    'isolates gateway failures and rejects mismatched result metadata',
    () async {
      final views = _views();
      final inspection = _inspection();

      final throwingLoader = ObjectSpriteAtlasLoader(
        gateway: _FakeGateway(throwOnRender: true),
      );
      final throwingContext = throwingLoader.createContext(
        metadataViews: views.metadata,
        objectViews: views.objects,
        assetState: _readyState(inspection),
      )!;
      final failed = await throwingLoader.loadBatch(
        context: throwingContext,
        operationId: 'object-atlas-failed',
        objectKeys: throwingContext.objectKeys,
      );
      expect(
        failed.diagnostics.single.code,
        ObjectSpriteAtlasDiagnosticCodes.gatewayFailed,
      );
      expect(failed.unsupportedObjects, hasLength(3));

      final mismatchLoader = ObjectSpriteAtlasLoader(
        gateway: _FakeGateway(mismatchOperationId: true),
      );
      final mismatchContext = mismatchLoader.createContext(
        metadataViews: views.metadata,
        objectViews: views.objects,
        assetState: _readyState(inspection),
      )!;
      final mismatch = await mismatchLoader.loadBatch(
        context: mismatchContext,
        operationId: 'object-atlas-mismatch',
        objectKeys: mismatchContext.objectKeys,
      );
      expect(
        mismatch.diagnostics.single.code,
        ObjectSpriteAtlasDiagnosticCodes.resultMismatch,
      );
    },
  );

  test(
    'rejects batches outside the context and unavailable settings',
    () async {
      final views = _views();
      final loader = ObjectSpriteAtlasLoader(gateway: _FakeGateway());
      expect(
        loader.createContext(
          metadataViews: views.metadata,
          objectViews: views.objects,
          assetState: StarCraftDataAssetSettingsState(
            status: StarCraftDataAssetSettingsStatus.unavailable,
          ),
        ),
        isNull,
      );

      final context = loader.createContext(
        metadataViews: views.metadata,
        objectViews: views.objects,
        assetState: _readyState(_inspection()),
      )!;
      expect(
        () => loader.loadBatch(
          context: context,
          operationId: 'object-atlas-invalid',
          objectKeys: [_key(StarCraftObjectGraphicKind.unit, 99)],
        ),
        throwsArgumentError,
      );
    },
  );
}

final class _FakeGateway implements StarCraftObjectAtlasGateway {
  _FakeGateway({
    this.unsupportedIds = const {},
    this.throwOnRender = false,
    this.mismatchOperationId = false,
  });

  final Set<int> unsupportedIds;
  final bool throwOnRender;
  final bool mismatchOperationId;
  final List<String> cancelled = [];

  @override
  Future<void> cancel(String operationId) async {
    cancelled.add(operationId);
  }

  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async {
    if (throwOnRender) {
      throw StateError('gateway failed');
    }
    final responseRequest = mismatchOperationId
        ? StarCraftObjectAtlasRequest(
            operationId: '${request.operationId}-other',
            installationPath: request.installationPath,
            tileset: request.tileset,
            objects: request.objects,
          )
        : request;
    return StarCraftObjectAtlasResult(
      request: responseRequest,
      entries: [
        for (final key in request.objects)
          if (!unsupportedIds.contains(key.id)) _entry(key),
      ],
      unsupportedObjects: [
        for (final key in request.objects)
          if (unsupportedIds.contains(key.id))
            StarCraftUnsupportedObjectGraphic(
              key: key,
              code: 'SC_CASC_OBJECT_GRP_MISSING',
            ),
      ],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.4.0',
      cascLibRevision: 'pinned-casc',
      totalAssetBytes: 4096,
    );
  }
}

StarCraftObjectAtlasEntry _entry(StarCraftObjectGraphicKey key) {
  return StarCraftObjectAtlasEntry(
    key: key,
    spriteId: key.id,
    imageId: key.id + 1,
    width: 2,
    height: 3,
    anchorX: 1,
    anchorY: 2,
    frameIndex: 0,
    rgbaBytes: Uint8List(2 * 3 * 4),
  );
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

({ChkMetadataViews metadata, ChkObjectViews objects}) _views() {
  final unitPayload = Uint8List(2 * ChkUnitPlacement.recordLength);
  final unitData = ByteData.sublistView(unitPayload);
  unitData
    ..setUint16(8, 5, Endian.little)
    ..setUint8(16, 0)
    ..setUint16(ChkUnitPlacement.recordLength + 8, 5, Endian.little)
    ..setUint8(ChkUnitPlacement.recordLength + 16, 0);

  final spritePayload = Uint8List(2 * ChkSpritePlacement.recordLength);
  final spriteData = ByteData.sublistView(spritePayload);
  spriteData
    ..setUint16(0, 7, Endian.little)
    ..setUint8(6, 1)
    ..setUint16(ChkSpritePlacement.recordLength, 8, Endian.little)
    ..setUint8(ChkSpritePlacement.recordLength + 6, 9)
    ..setUint16(
      ChkSpritePlacement.recordLength + 8,
      ChkSpritePlacement.drawAsSpriteFlag,
      Endian.little,
    );

  final document = _documentFromSections([
    _section('ERA ', [4, 0]),
    _section('UNIT', unitPayload),
    _section('THG2', spritePayload),
  ]);
  return (
    metadata: const ChkMetadataViewDecoder().decode(document),
    objects: const ChkObjectViewDecoder().decode(document),
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
    helperVersion: '0.4.0',
    cascLibRevision: 'pinned-casc',
  );
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
