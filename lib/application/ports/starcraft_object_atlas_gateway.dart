import 'dart:typed_data';

import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class StarCraftObjectAtlasDiagnosticCodes {
  static const installationPathInvalid = 'SC_CASC_INSTALLATION_PATH_INVALID';
  static const helperNotFound = 'SC_CASC_HELPER_NOT_FOUND';
  static const helperStartFailed = 'SC_CASC_HELPER_START_FAILED';
  static const helperTimedOut = 'SC_CASC_HELPER_TIMED_OUT';
  static const helperCancelled = 'SC_CASC_HELPER_CANCELLED';
  static const helperOutputLimitExceeded =
      'SC_CASC_HELPER_OUTPUT_LIMIT_EXCEEDED';
  static const helperInvalidResponse = 'SC_CASC_HELPER_INVALID_RESPONSE';
  static const storageOpenFailed = 'SC_CASC_STORAGE_OPEN_FAILED';
  static const storageInfoFailed = 'SC_CASC_STORAGE_INFO_FAILED';
  static const atlasOutputInvalid = 'SC_CASC_OBJECT_ATLAS_OUTPUT_INVALID';
  static const renderFailed = 'SC_CASC_OBJECT_RENDER_FAILED';
}

abstract interface class StarCraftObjectAtlasGateway {
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  );

  Future<void> cancel(String operationId);
}

enum StarCraftObjectGraphicKind {
  unit(0, 'unit'),
  sprite(1, 'sprite');

  const StarCraftObjectGraphicKind(this.rawValue, this.wireName);

  final int rawValue;
  final String wireName;
}

enum StarCraftObjectFramePolicy {
  firstFrame('firstFrame', 0);

  const StarCraftObjectFramePolicy(this.wireName, this.frameIndex);

  final String wireName;
  final int frameIndex;
}

abstract final class StarCraftObjectPreviewPolicy {
  static const framePolicy = StarCraftObjectFramePolicy.firstFrame;
  static const direction = 0;
  static const minimumPlayerColor = 0;
  static const maximumPlayerColor = 7;
  static const neutralPlayerColorValue = 0xff;

  static int? playerColorForOwner(int owner) {
    return owner >= minimumPlayerColor && owner <= maximumPlayerColor
        ? owner
        : null;
  }
}

final class StarCraftObjectGraphicKey
    implements Comparable<StarCraftObjectGraphicKey> {
  const StarCraftObjectGraphicKey({
    required this.kind,
    required this.id,
    this.playerColor,
    this.direction = StarCraftObjectPreviewPolicy.direction,
  }) : assert(id >= 0 && id <= 0xffff),
       assert(
         playerColor == null ||
             (playerColor >= StarCraftObjectPreviewPolicy.minimumPlayerColor &&
                 playerColor <=
                     StarCraftObjectPreviewPolicy.maximumPlayerColor),
       ),
       assert(direction == StarCraftObjectPreviewPolicy.direction);

  final StarCraftObjectGraphicKind kind;
  final int id;
  final int? playerColor;
  final int direction;

  int get playerColorSortValue =>
      playerColor ?? StarCraftObjectPreviewPolicy.neutralPlayerColorValue;

  @override
  int compareTo(StarCraftObjectGraphicKey other) {
    var comparison = kind.rawValue.compareTo(other.kind.rawValue);
    if (comparison != 0) {
      return comparison;
    }
    comparison = id.compareTo(other.id);
    if (comparison != 0) {
      return comparison;
    }
    comparison = playerColorSortValue.compareTo(other.playerColorSortValue);
    if (comparison != 0) {
      return comparison;
    }
    return direction.compareTo(other.direction);
  }

  @override
  bool operator ==(Object other) {
    return other is StarCraftObjectGraphicKey &&
        other.kind == kind &&
        other.id == id &&
        other.playerColor == playerColor &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(kind, id, playerColor, direction);
}

final class StarCraftObjectAtlasRequest {
  StarCraftObjectAtlasRequest({
    required this.operationId,
    required this.installationPath,
    required this.tileset,
    required List<StarCraftObjectGraphicKey> objects,
    this.framePolicy = StarCraftObjectPreviewPolicy.framePolicy,
  }) : objects = List.unmodifiable(objects) {
    if (!_isValidOperationId(operationId)) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must contain 1-128 safe ASCII identifier characters.',
      );
    }
    if (installationPath.trim().isEmpty) {
      throw ArgumentError.value(
        installationPath,
        'installationPath',
        'Must not be empty.',
      );
    }
    if (this.objects.isEmpty || this.objects.length > maximumObjects) {
      throw RangeError.range(
        this.objects.length,
        1,
        maximumObjects,
        'objects.length',
      );
    }
    _expectStrictlyIncreasingKeys(this.objects, 'objects');
  }

  static const maximumObjects = 256;

  final String operationId;
  final String installationPath;
  final StarCraftTilesetAssetSet tileset;
  final List<StarCraftObjectGraphicKey> objects;
  final StarCraftObjectFramePolicy framePolicy;
}

final class StarCraftObjectAtlasEntry {
  StarCraftObjectAtlasEntry({
    required this.key,
    required this.spriteId,
    required this.imageId,
    required this.width,
    required this.height,
    required this.anchorX,
    required this.anchorY,
    required this.frameIndex,
    required Uint8List rgbaBytes,
  }) : rgbaBytes = Uint8List.fromList(rgbaBytes).asUnmodifiableView() {
    if (spriteId < 0 ||
        spriteId > 0xffff ||
        imageId < 0 ||
        imageId > 0xffff ||
        width <= 0 ||
        width > maximumDimension ||
        height <= 0 ||
        height > maximumDimension ||
        anchorX < -0x8000 ||
        anchorX > 0x7fff ||
        anchorY < -0x8000 ||
        anchorY > 0x7fff ||
        frameIndex != StarCraftObjectPreviewPolicy.framePolicy.frameIndex ||
        this.rgbaBytes.length != width * height * bytesPerPixel ||
        this.rgbaBytes.length > maximumFrameBytes) {
      throw ArgumentError('Object atlas entry metadata is inconsistent.');
    }
  }

  static const maximumDimension = 1024;
  static const maximumFrameBytes = 4 * 1024 * 1024;
  static const bytesPerPixel = 4;

  final StarCraftObjectGraphicKey key;
  final int spriteId;
  final int imageId;
  final int width;
  final int height;
  final int anchorX;
  final int anchorY;
  final int frameIndex;
  final Uint8List rgbaBytes;
}

final class StarCraftUnsupportedObjectGraphic {
  const StarCraftUnsupportedObjectGraphic({
    required this.key,
    required this.code,
  }) : assert(code.length > 0 && code.length <= 128);

  final StarCraftObjectGraphicKey key;
  final String code;
}

final class StarCraftObjectAtlasResult {
  StarCraftObjectAtlasResult({
    required this.request,
    required List<StarCraftObjectAtlasEntry> entries,
    required List<StarCraftUnsupportedObjectGraphic> unsupportedObjects,
    this.storageProduct,
    this.storageBuildNumber,
    this.helperVersion,
    this.cascLibRevision,
    this.totalAssetBytes = 0,
    List<EditorDiagnostic> diagnostics = const [],
  }) : entries = List.unmodifiable(entries),
       unsupportedObjects = List.unmodifiable(unsupportedObjects),
       diagnostics = List.unmodifiable(diagnostics) {
    if (totalAssetBytes < 0) {
      throw ArgumentError.value(
        totalAssetBytes,
        'totalAssetBytes',
        'Must not be negative.',
      );
    }
    _expectStrictlyIncreasingKeys(
      this.entries.map((entry) => entry.key).toList(growable: false),
      'entries',
    );
    _expectStrictlyIncreasingKeys(
      this.unsupportedObjects
          .map((unsupported) => unsupported.key)
          .toList(growable: false),
      'unsupportedObjects',
    );
    for (final unsupported in this.unsupportedObjects) {
      if (!unsupported.code.startsWith('SC_CASC_OBJECT_') ||
          unsupported.code.length > 128) {
        throw ArgumentError.value(
          unsupported.code,
          'unsupportedObjects.code',
          'Must be a stable SC_CASC_OBJECT_* diagnostic code.',
        );
      }
    }
    final covered = <StarCraftObjectGraphicKey>[
      ...this.entries.map((entry) => entry.key),
      ...this.unsupportedObjects.map((unsupported) => unsupported.key),
    ]..sort();
    if (!_sameKeys(covered, request.objects)) {
      throw ArgumentError(
        'Rendered and unsupported objects must cover the request exactly.',
      );
    }
  }

  factory StarCraftObjectAtlasResult.failed({
    required StarCraftObjectAtlasRequest request,
    required EditorDiagnostic diagnostic,
  }) {
    return StarCraftObjectAtlasResult(
      request: request,
      entries: const [],
      unsupportedObjects: [
        for (final key in request.objects)
          StarCraftUnsupportedObjectGraphic(
            key: key,
            code: StarCraftObjectAtlasDiagnosticCodes.renderFailed,
          ),
      ],
      diagnostics: [diagnostic],
    );
  }

  final StarCraftObjectAtlasRequest request;
  final List<StarCraftObjectAtlasEntry> entries;
  final List<StarCraftUnsupportedObjectGraphic> unsupportedObjects;
  final String? storageProduct;
  final int? storageBuildNumber;
  final String? helperVersion;
  final String? cascLibRevision;
  final int totalAssetBytes;
  final List<EditorDiagnostic> diagnostics;

  bool get isSuccess => diagnostics.isEmpty;
}

void _expectStrictlyIncreasingKeys(
  List<StarCraftObjectGraphicKey> keys,
  String name,
) {
  StarCraftObjectGraphicKey? previous;
  for (final key in keys) {
    if (key.id < 0 ||
        key.id > 0xffff ||
        (key.playerColor != null &&
            (key.playerColor! <
                    StarCraftObjectPreviewPolicy.minimumPlayerColor ||
                key.playerColor! >
                    StarCraftObjectPreviewPolicy.maximumPlayerColor)) ||
        key.direction != StarCraftObjectPreviewPolicy.direction ||
        (previous != null && previous.compareTo(key) >= 0)) {
      throw ArgumentError.value(
        keys,
        name,
        'Must contain sorted unique supported object keys.',
      );
    }
    previous = key;
  }
}

bool _sameKeys(
  List<StarCraftObjectGraphicKey> left,
  List<StarCraftObjectGraphicKey> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _isValidOperationId(String value) {
  if (value.isEmpty || value.length > 128) {
    return false;
  }
  for (final codeUnit in value.codeUnits) {
    final isLetter =
        (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a);
    final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
    if (!isLetter &&
        !isDigit &&
        codeUnit != 0x2d &&
        codeUnit != 0x2e &&
        codeUnit != 0x5f) {
      return false;
    }
  }
  return true;
}
