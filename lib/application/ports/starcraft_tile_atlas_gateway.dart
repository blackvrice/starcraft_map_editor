import 'dart:typed_data';

import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class StarCraftTileAtlasDiagnosticCodes {
  static const installationPathInvalid = 'SC_CASC_INSTALLATION_PATH_INVALID';
  static const storageOpenFailed = 'SC_CASC_STORAGE_OPEN_FAILED';
  static const storageInfoFailed = 'SC_CASC_STORAGE_INFO_FAILED';
  static const assetMissing = 'SC_CASC_TILE_ASSET_MISSING';
  static const assetInvalid = 'SC_CASC_TILE_ASSET_INVALID';
  static const helperNotFound = 'SC_CASC_HELPER_NOT_FOUND';
  static const helperStartFailed = 'SC_CASC_HELPER_START_FAILED';
  static const helperTimedOut = 'SC_CASC_HELPER_TIMED_OUT';
  static const helperOutputLimitExceeded =
      'SC_CASC_HELPER_OUTPUT_LIMIT_EXCEEDED';
  static const helperInvalidResponse = 'SC_CASC_HELPER_INVALID_RESPONSE';
  static const atlasOutputInvalid = 'SC_CASC_TILE_ATLAS_OUTPUT_INVALID';
  static const renderFailed = 'SC_CASC_TILE_RENDER_FAILED';
}

abstract interface class StarCraftTileAtlasGateway {
  Future<StarCraftTileAtlasResult> render(StarCraftTileAtlasRequest request);
}

final class StarCraftTileAtlasRequest {
  StarCraftTileAtlasRequest({
    required this.installationPath,
    required this.tileset,
    required List<int> rawValues,
  }) : rawValues = List.unmodifiable(rawValues) {
    if (installationPath.trim().isEmpty) {
      throw ArgumentError.value(
        installationPath,
        'installationPath',
        'Must not be empty.',
      );
    }
    if (this.rawValues.isEmpty || this.rawValues.length > maximumRawValues) {
      throw RangeError.range(
        this.rawValues.length,
        1,
        maximumRawValues,
        'rawValues.length',
      );
    }
    var previous = -1;
    for (final value in this.rawValues) {
      if (value < 0 || value > 0xFFFF) {
        throw RangeError.range(value, 0, 0xFFFF, 'rawValues');
      }
      if (value <= previous) {
        throw ArgumentError.value(
          rawValues,
          'rawValues',
          'Must be sorted in strictly increasing order.',
        );
      }
      previous = value;
    }
  }

  static const maximumRawValues = 4096;

  final String installationPath;
  final StarCraftTilesetAssetSet tileset;
  final List<int> rawValues;
}

final class StarCraftTileAtlasResult {
  StarCraftTileAtlasResult({
    required this.request,
    required this.tileSize,
    required this.columns,
    required this.rows,
    required List<int> rawValues,
    required Uint8List rgbaBytes,
    required List<int> unsupportedRawValues,
    this.storageProduct,
    this.storageBuildNumber,
    this.helperVersion,
    this.cascLibRevision,
    this.totalAssetBytes = 0,
    List<EditorDiagnostic> diagnostics = const [],
  }) : rawValues = List.unmodifiable(rawValues),
       rgbaBytes = Uint8List.fromList(rgbaBytes).asUnmodifiableView(),
       unsupportedRawValues = List.unmodifiable(unsupportedRawValues),
       diagnostics = List.unmodifiable(diagnostics) {
    if (tileSize != expectedTileSize ||
        columns < 0 ||
        rows < 0 ||
        totalAssetBytes < 0) {
      throw ArgumentError('Tile atlas dimensions and sizes must be valid.');
    }
    if (this.rawValues.isEmpty) {
      if (columns != 0 || rows != 0 || this.rgbaBytes.isNotEmpty) {
        throw ArgumentError(
          'An empty atlas must have no dimensions or pixels.',
        );
      }
    } else {
      if (columns <= 0 ||
          rows <= 0 ||
          this.rawValues.length > columns * rows ||
          this.rgbaBytes.length !=
              columns * rows * tileSize * tileSize * bytesPerPixel) {
        throw ArgumentError('Atlas pixels do not match its declared grid.');
      }
    }
    _expectStrictlyIncreasing(this.rawValues, 'rawValues');
    if (this.rawValues.any((value) => value >= 0x4000)) {
      throw ArgumentError.value(
        this.rawValues,
        'rawValues',
        'Rendered values must stay inside the CV5 group range.',
      );
    }
    _expectStrictlyIncreasing(
      this.unsupportedRawValues,
      'unsupportedRawValues',
    );
    final covered = [...this.rawValues, ...this.unsupportedRawValues]..sort();
    if (!_sameValues(covered, request.rawValues)) {
      throw ArgumentError(
        'Rendered and unsupported values must cover the request exactly.',
      );
    }
  }

  factory StarCraftTileAtlasResult.failed({
    required StarCraftTileAtlasRequest request,
    required EditorDiagnostic diagnostic,
  }) {
    return StarCraftTileAtlasResult(
      request: request,
      tileSize: expectedTileSize,
      columns: 0,
      rows: 0,
      rawValues: const [],
      rgbaBytes: Uint8List(0),
      unsupportedRawValues: request.rawValues,
      diagnostics: [diagnostic],
    );
  }

  static const expectedTileSize = 32;
  static const bytesPerPixel = 4;

  final StarCraftTileAtlasRequest request;
  final int tileSize;
  final int columns;
  final int rows;
  final List<int> rawValues;
  final Uint8List rgbaBytes;
  final List<int> unsupportedRawValues;
  final String? storageProduct;
  final int? storageBuildNumber;
  final String? helperVersion;
  final String? cascLibRevision;
  final int totalAssetBytes;
  final List<EditorDiagnostic> diagnostics;

  bool get isSuccess => diagnostics.isEmpty;
}

void _expectStrictlyIncreasing(List<int> values, String name) {
  var previous = -1;
  for (final value in values) {
    if (value < 0 || value > 0xFFFF || value <= previous) {
      throw ArgumentError.value(values, name, 'Must be sorted unique u16.');
    }
    previous = value;
  }
}

bool _sameValues(List<int> left, List<int> right) {
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
