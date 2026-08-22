import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../application/ports/starcraft_placement_catalog_gateway.dart';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import 'starcraft_data_helper_protocol.dart';

final class ProcessStarCraftPlacementCatalogGateway
    implements StarCraftPlacementCatalogGateway {
  ProcessStarCraftPlacementCatalogGateway({
    required this.helperExecutablePath,
    List<String> helperArguments = const [],
    this.timeout = const Duration(seconds: 30),
    this.maximumProcessOutputBytes = 256 * 1024,
    Map<String, String>? parentEnvironment,
    List<String> additionalInheritedEnvironmentKeys = const [],
  }) : helperArguments = List.unmodifiable(helperArguments),
       additionalInheritedEnvironmentKeys = List.unmodifiable(
         additionalInheritedEnvironmentKeys,
       ),
       parentEnvironment = Map.unmodifiable(
         parentEnvironment ?? Platform.environment,
       ) {
    if (!_isAbsoluteWindowsPath(helperExecutablePath)) {
      throw ArgumentError.value(
        helperExecutablePath,
        'helperExecutablePath',
        'The helper executable path must be absolute.',
      );
    }
    if (timeout <= Duration.zero || maximumProcessOutputBytes <= 0) {
      throw ArgumentError('Timeout and output limits must be positive.');
    }
  }

  factory ProcessStarCraftPlacementCatalogGateway.bundled() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    return ProcessStarCraftPlacementCatalogGateway(
      helperExecutablePath:
          '$executableDirectory${Platform.pathSeparator}'
          'starcraft_data_helper.exe',
    );
  }

  static const protocolVersion = StarCraftDataHelperProtocol.version;
  static const helperVersion = StarCraftDataHelperProtocol.helperVersion;
  static const cascLibRevision = StarCraftDataHelperProtocol.cascLibRevision;
  static const maximumTotalAssetBytes = 256 * 1024 * 1024;
  static const classicUnitCount = 228;
  static const classicSpriteCount = 517;
  static const _operation = 'listPlacementCatalog';

  final String helperExecutablePath;
  final List<String> helperArguments;
  final Duration timeout;
  final int maximumProcessOutputBytes;
  final Map<String, String> parentEnvironment;
  final List<String> additionalInheritedEnvironmentKeys;

  final Map<String, Process> _activeProcesses = {};
  final Set<String> _reservedOperations = {};
  final Set<String> _cancelledOperations = {};

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    if (!_isAbsoluteWindowsPath(request.installationPath) ||
        request.installationPath.trim() != request.installationPath) {
      return _failure(
        request,
        code: StarCraftPlacementCatalogDiagnosticCodes.installationPathInvalid,
        message: 'The StarCraft installation path is invalid.',
        filePath: request.installationPath,
        remediation: 'Choose the StarCraft installation folder again.',
      );
    }
    if (request.kind != StarCraftPlacementKind.tile &&
        request.kind != StarCraftPlacementKind.unit &&
        request.kind != StarCraftPlacementKind.pureSprite) {
      return _failure(
        request,
        code: StarCraftPlacementCatalogDiagnosticCodes.listingFailed,
        message: 'This helper version does not support that catalog kind.',
        filePath: request.installationPath,
        remediation: 'Choose the Tile, Unit, or pure Sprite catalog.',
      );
    }
    if (_reservedOperations.contains(request.operationId)) {
      return _failure(
        request,
        code: StarCraftPlacementCatalogDiagnosticCodes.listingFailed,
        message: 'A catalog operation with this ID is already active.',
        filePath: request.installationPath,
        remediation: 'Wait for the active catalog operation to finish.',
      );
    }
    _reservedOperations.add(request.operationId);

    Process? process;
    Directory? temporaryDirectory;
    try {
      if (!await File(helperExecutablePath).exists()) {
        return _failure(
          request,
          code: StarCraftPlacementCatalogDiagnosticCodes.helperNotFound,
          message: 'The bundled StarCraft CASC helper is missing.',
          filePath: helperExecutablePath,
          remediation: 'Repair or reinstall the application.',
        );
      }
      if (_cancelledOperations.contains(request.operationId)) {
        return _cancelledFailure(request);
      }
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_catalog_',
      );
      process = await Process.start(
        helperExecutablePath,
        helperArguments,
        workingDirectory: temporaryDirectory.path,
        environment: _minimalEnvironment(temporaryDirectory.path),
        includeParentEnvironment: false,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
      _activeProcesses[request.operationId] = process;
      if (_cancelledOperations.contains(request.operationId)) {
        process.kill(ProcessSignal.sigkill);
        await _waitForTermination(process);
        return _cancelledFailure(request);
      }
      final stdoutFuture = _captureOutput(process.stdout);
      final stderrFuture = _captureOutput(process.stderr);
      process.stdin.writeln(
        jsonEncode({
          'protocolVersion': protocolVersion,
          'requestId': request.operationId,
          'operation': _operation,
          'installationPath': request.installationPath,
          'kind': request.kind.wireName,
          'tileset': request.tileset.rawValue,
          'offset': request.offset,
          'limit': request.limit,
        }),
      );
      await process.stdin.flush();
      await process.stdin.close();

      final int exitCode;
      try {
        exitCode = await process.exitCode.timeout(timeout);
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await _waitForTermination(process);
        final stderr = await stderrFuture;
        await stdoutFuture;
        return _failure(
          request,
          code: StarCraftPlacementCatalogDiagnosticCodes.helperTimedOut,
          message: 'The StarCraft catalog helper timed out.',
          filePath: request.installationPath,
          remediation: 'Repair the StarCraft installation and retry.',
          rawDetails: _rawProcessDetails(stderr: stderr),
        );
      }

      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      if (_cancelledOperations.remove(request.operationId)) {
        return _cancelledFailure(
          request,
          rawDetails: _rawProcessDetails(exitCode: exitCode, stderr: stderr),
        );
      }
      if (stdout.exceededLimit || stderr.exceededLimit) {
        return _failure(
          request,
          code: StarCraftPlacementCatalogDiagnosticCodes
              .helperOutputLimitExceeded,
          message: 'The StarCraft catalog helper produced too much output.',
          filePath: request.installationPath,
          remediation: 'Repair the application or report the helper error.',
          rawDetails: _rawProcessDetails(exitCode: exitCode, stderr: stderr),
        );
      }
      return _parseResponse(
        request: request,
        stdout: stdout.text,
        stderr: stderr,
        exitCode: exitCode,
      );
    } on ProcessException catch (error) {
      if (_cancelledOperations.remove(request.operationId)) {
        return _cancelledFailure(request);
      }
      return _failure(
        request,
        code: StarCraftPlacementCatalogDiagnosticCodes.helperStartFailed,
        message: 'The StarCraft catalog helper could not be started.',
        filePath: helperExecutablePath,
        remediation: 'Repair or reinstall the application.',
        rawDetails: error.errorCode.toString(),
      );
    } on FileSystemException catch (error) {
      return _failure(
        request,
        code: StarCraftPlacementCatalogDiagnosticCodes.listingFailed,
        message: 'The StarCraft catalog could not be listed safely.',
        filePath: error.path ?? request.installationPath,
        remediation: 'Check directory permissions and retry.',
        rawDetails: error.toString(),
      );
    } finally {
      if (process != null &&
          identical(_activeProcesses[request.operationId], process)) {
        _activeProcesses.remove(request.operationId);
      }
      _reservedOperations.remove(request.operationId);
      _cancelledOperations.remove(request.operationId);
      if (temporaryDirectory != null) {
        try {
          await temporaryDirectory.delete(recursive: true);
        } on FileSystemException {
          // Never widen cleanup beyond this exact app-created directory.
        }
      }
    }
  }

  @override
  Future<void> cancel(String operationId) async {
    if (!_reservedOperations.contains(operationId)) {
      return;
    }
    _cancelledOperations.add(operationId);
    final process = _activeProcesses.remove(operationId);
    if (process == null) {
      return;
    }
    process.kill(ProcessSignal.sigkill);
    await _waitForTermination(process);
  }

  StarCraftPlacementCatalogPage _parseResponse({
    required StarCraftPlacementCatalogRequest request,
    required String stdout,
    required _CapturedOutput stderr,
    required int exitCode,
  }) {
    try {
      final lines = const LineSplitter()
          .convert(stdout)
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.length != 1) {
        throw const FormatException('Expected exactly one JSON response.');
      }
      final decoded = jsonDecode(lines.single);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Helper response must be an object.');
      }
      _expectBaseResponse(decoded, request.operationId);
      if (decoded['status'] == 'error') {
        return _parseErrorResponse(
          request,
          decoded,
          stderr: stderr,
          exitCode: exitCode,
        );
      }
      if (decoded['status'] != 'success' || exitCode != 0) {
        throw FormatException(
          'Unexpected helper status or exit code: '
          '${decoded['status']}/$exitCode.',
        );
      }

      final installation = _jsonObject(decoded, 'installation');
      if (!_sameWindowsPath(
        _jsonString(installation, 'path'),
        request.installationPath,
      )) {
        throw const FormatException('Installation path does not match.');
      }
      final storageProduct = _jsonString(installation, 'storageProduct');
      final storageBuildNumber = _jsonInteger(
        installation,
        'storageBuildNumber',
      );
      if (storageProduct.trim() != storageProduct ||
          storageProduct.length > 64 ||
          storageBuildNumber < 0 ||
          storageBuildNumber > 0xFFFFFFFF ||
          _jsonString(decoded, 'kind') != request.kind.wireName ||
          _jsonInteger(decoded, 'tileset') != request.tileset.rawValue) {
        throw const FormatException('Catalog identity metadata is invalid.');
      }

      final assets = _jsonObject(decoded, 'assets');
      final readCount = _jsonInteger(assets, 'readCount');
      final totalBytes = _jsonInteger(assets, 'totalBytes');
      final validReadCount = request.kind == StarCraftPlacementKind.tile
          ? readCount == StarCraftDataAssetManifest.renderAssetKinds.length
          : readCount >= 7 &&
                readCount <= 7 + StarCraftPlacementCatalogRequest.maximumLimit;
      if (!validReadCount ||
          totalBytes <= 0 ||
          totalBytes > maximumTotalAssetBytes) {
        throw const FormatException('Catalog asset metadata is invalid.');
      }

      final catalog = _jsonObject(decoded, 'catalog');
      final offset = _jsonInteger(catalog, 'offset');
      final limit = _jsonInteger(catalog, 'limit');
      final totalEntries = _jsonInteger(catalog, 'totalEntries');
      final expectedTotalEntries = switch (request.kind) {
        StarCraftPlacementKind.unit => classicUnitCount,
        StarCraftPlacementKind.pureSprite => classicSpriteCount,
        _ => null,
      };
      if (offset != request.offset ||
          limit != request.limit ||
          totalEntries < 0 ||
          totalEntries > StarCraftPlacementCatalogPage.maximumTotalEntries ||
          (expectedTotalEntries != null &&
              totalEntries != expectedTotalEntries)) {
        throw const FormatException('Catalog page metadata is invalid.');
      }
      final expectedLength = request.offset >= totalEntries
          ? 0
          : (totalEntries - request.offset).clamp(0, request.limit);
      final rawEntries = decoded['entries'];
      if (rawEntries is! List || rawEntries.length != expectedLength) {
        throw const FormatException('Catalog page length is invalid.');
      }
      final entries = <StarCraftPlacementCatalogEntry>[];
      for (var index = 0; index < rawEntries.length; index++) {
        final item = rawEntries[index];
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Catalog entry must be an object.');
        }
        final id = _jsonInteger(item, 'id');
        if (id != request.offset + index || id < 0 || id > 0xFFFF) {
          throw const FormatException('Catalog IDs must be contiguous u16s.');
        }
        final String? previewIssueCode;
        if (request.kind == StarCraftPlacementKind.tile) {
          previewIssueCode = null;
        } else {
          previewIssueCode = _jsonNullableString(item, 'previewIssueCode');
          if (previewIssueCode != null &&
              (!previewIssueCode.startsWith('SC_CASC_OBJECT_') ||
                  previewIssueCode.length >
                      StarCraftPlacementCatalogEntry
                          .maximumPreviewCodeLength)) {
            throw const FormatException(
              'Object preview issue code is invalid.',
            );
          }
        }
        final key = switch (request.kind) {
          StarCraftPlacementKind.tile => StarCraftPlacementCatalogKey.tile(
            tileset: request.tileset,
            rawValue: id,
          ),
          StarCraftPlacementKind.unit => StarCraftPlacementCatalogKey.unit(id),
          StarCraftPlacementKind.pureSprite =>
            StarCraftPlacementCatalogKey.pureSprite(id),
          _ => throw const FormatException('Unsupported catalog kind.'),
        };
        final placementIssue = request.kind == StarCraftPlacementKind.tile
            ? null
            : StarCraftPlacementCatalogIssue(
                code: previewIssueCode == null
                    ? 'SC_CATALOG_ITEM_PLACEMENT_FACTORY_PENDING'
                    : 'SC_CATALOG_ITEM_OBJECT_GRAPHIC_UNAVAILABLE',
                message: previewIssueCode == null
                    ? 'Placement defaults are not implemented yet.'
                    : 'The local object preview is unavailable.',
              );
        entries.add(
          StarCraftPlacementCatalogEntry(
            key: key,
            source: StarCraftPlacementCatalogSource.localData,
            availability: request.kind == StarCraftPlacementKind.tile
                ? StarCraftPlacementAvailability.placeable
                : StarCraftPlacementAvailability.unsupported,
            issue: placementIssue,
            previewIssueCode: previewIssueCode,
          ),
        );
      }
      return StarCraftPlacementCatalogPage(
        request: request,
        totalEntries: totalEntries,
        entries: entries,
        storageProduct: storageProduct,
        storageBuildNumber: storageBuildNumber,
        helperVersion: helperVersion,
        cascLibRevision: cascLibRevision,
        totalMetadataBytes: totalBytes,
      );
    } on FormatException catch (error) {
      return _failure(
        request,
        code: StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
        message: 'The StarCraft catalog helper returned an invalid response.',
        filePath: request.installationPath,
        remediation: 'Repair the application or report the helper error.',
        rawDetails: _rawProcessDetails(
          exitCode: exitCode,
          stderr: stderr,
          parserError: error.message,
        ),
      );
    }
  }

  void _expectBaseResponse(Map<String, dynamic> response, String requestId) {
    if (_jsonInteger(response, 'protocolVersion') != protocolVersion ||
        _jsonString(response, 'requestId') != requestId ||
        _jsonString(response, 'operation') != _operation ||
        _jsonString(response, 'helperVersion') != helperVersion ||
        _jsonString(response, 'cascLibRevision') != cascLibRevision) {
      throw const FormatException('Helper protocol metadata does not match.');
    }
  }

  StarCraftPlacementCatalogPage _parseErrorResponse(
    StarCraftPlacementCatalogRequest request,
    Map<String, dynamic> response, {
    required _CapturedOutput stderr,
    required int exitCode,
  }) {
    if (exitCode == 0) {
      throw const FormatException('Error response exited successfully.');
    }
    final error = _jsonObject(response, 'error');
    final nativeCode = _jsonString(error, 'code');
    final message = _jsonString(error, 'message');
    final stage = _jsonString(error, 'stage');
    final nativeError = _jsonInteger(error, 'nativeError');
    if (!_helperErrorCodes.contains(nativeCode) ||
        nativeError < 0 ||
        nativeError > 0xFFFFFFFF) {
      throw const FormatException('Helper returned an unknown error.');
    }
    final code = switch (nativeCode) {
      'SC_CASC_STORAGE_OPEN_FAILED' =>
        StarCraftPlacementCatalogDiagnosticCodes.storageOpenFailed,
      'SC_CASC_ASSET_MISSING' ||
      'SC_CASC_TILE_ASSET_MISSING' ||
      'SC_CASC_OBJECT_METADATA_MISSING' ||
      'SC_CASC_OBJECT_PALETTE_MISSING' =>
        StarCraftPlacementCatalogDiagnosticCodes.metadataMissing,
      'SC_CASC_ASSET_INVALID' ||
      'SC_CASC_TILE_ASSET_INVALID' ||
      'SC_CASC_TILE_CATALOG_INVALID' ||
      'SC_CASC_OBJECT_METADATA_INVALID' ||
      'SC_CASC_OBJECT_PALETTE_INVALID' ||
      'SC_CASC_OBJECT_ASSETS_TOO_LARGE' ||
      'SC_CASC_OBJECT_CATALOG_INVALID' =>
        StarCraftPlacementCatalogDiagnosticCodes.metadataInvalid,
      _ => StarCraftPlacementCatalogDiagnosticCodes.listingFailed,
    };
    return _failure(
      request,
      code: code,
      message: message,
      filePath: request.installationPath,
      remediation:
          code == StarCraftPlacementCatalogDiagnosticCodes.storageOpenFailed
          ? 'Repair the StarCraft installation in Battle.net and retry.'
          : 'Repair the application or report the catalog helper error.',
      rawDetails: _rawProcessDetails(
        exitCode: exitCode,
        stderr: stderr,
        helperStage: stage,
        nativeError: nativeError,
        nativeCode: nativeCode,
      ),
    );
  }

  Future<_CapturedOutput> _captureOutput(Stream<List<int>> stream) async {
    final bytes = <int>[];
    var exceededLimit = false;
    await for (final chunk in stream) {
      final available = maximumProcessOutputBytes - bytes.length;
      if (available <= 0) {
        exceededLimit = true;
      } else if (chunk.length > available) {
        bytes.addAll(chunk.take(available));
        exceededLimit = true;
      } else {
        bytes.addAll(chunk);
      }
    }
    return _CapturedOutput(
      text: utf8.decode(bytes, allowMalformed: true),
      exceededLimit: exceededLimit,
    );
  }

  Future<void> _waitForTermination(Process process) async {
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // The process was force-killed. Never block indefinitely.
    }
  }

  Map<String, String> _minimalEnvironment(String temporaryPath) {
    final environment = <String, String>{
      'TEMP': temporaryPath,
      'TMP': temporaryPath,
    };
    final systemRoot = parentEnvironment['SystemRoot'];
    if (systemRoot != null && systemRoot.isNotEmpty) {
      environment['SystemRoot'] = systemRoot;
    }
    for (final key in additionalInheritedEnvironmentKeys) {
      final value = parentEnvironment[key];
      if (value != null && value.isNotEmpty) {
        environment[key] = value;
      }
    }
    return environment;
  }
}

const _helperErrorCodes = {
  'SC_CASC_INSTALLATION_NOT_FOUND',
  'SC_CASC_INSTALLATION_NOT_DIRECTORY',
  'SC_CASC_STORAGE_OPEN_FAILED',
  'SC_CASC_STORAGE_INFO_FAILED',
  'SC_CASC_ASSET_MISSING',
  'SC_CASC_ASSET_INVALID',
  'SC_CASC_TILE_ASSET_MISSING',
  'SC_CASC_TILE_ASSET_INVALID',
  'SC_CASC_TILE_CATALOG_INVALID',
  'SC_CASC_OBJECT_METADATA_MISSING',
  'SC_CASC_OBJECT_METADATA_INVALID',
  'SC_CASC_OBJECT_PALETTE_MISSING',
  'SC_CASC_OBJECT_PALETTE_INVALID',
  'SC_CASC_OBJECT_ASSETS_TOO_LARGE',
  'SC_CASC_OBJECT_CATALOG_INVALID',
  'SC_CASC_PROTOCOL_INVALID_CATALOG_PAGE',
  'SC_CASC_PROTOCOL_CATALOG_KIND_UNSUPPORTED',
};

final class _CapturedOutput {
  const _CapturedOutput({required this.text, required this.exceededLimit});

  final String text;
  final bool exceededLimit;
}

StarCraftPlacementCatalogPage _failure(
  StarCraftPlacementCatalogRequest request, {
  required String code,
  required String message,
  required String filePath,
  required String remediation,
  String? rawDetails,
}) => StarCraftPlacementCatalogPage.failed(
  request: request,
  diagnostic: EditorDiagnostic(
    code: code,
    message: message,
    severity: DiagnosticSeverity.warning,
    stage: DiagnosticStage.validate,
    filePath: filePath,
    remediation: remediation,
    rawDetails: rawDetails,
  ),
);

StarCraftPlacementCatalogPage _cancelledFailure(
  StarCraftPlacementCatalogRequest request, {
  String? rawDetails,
}) => _failure(
  request,
  code: StarCraftPlacementCatalogDiagnosticCodes.helperCancelled,
  message: 'The StarCraft catalog operation was cancelled.',
  filePath: request.installationPath,
  remediation: 'Retry the catalog operation when ready.',
  rawDetails: rawDetails,
);

Map<String, dynamic> _jsonObject(Map<String, dynamic> value, String key) {
  final object = value[key];
  if (object is! Map<String, dynamic>) {
    throw FormatException('$key must be a JSON object.');
  }
  return object;
}

String _jsonString(Map<String, dynamic> value, String key) {
  final string = value[key];
  if (string is! String || string.isEmpty || string.length > 4096) {
    throw FormatException('$key must be a bounded nonempty string.');
  }
  return string;
}

int _jsonInteger(Map<String, dynamic> value, String key) {
  final integer = value[key];
  if (integer is! int) {
    throw FormatException('$key must be an integer.');
  }
  return integer;
}

String? _jsonNullableString(Map<String, dynamic> value, String key) {
  if (!value.containsKey(key)) {
    throw FormatException('$key is required.');
  }
  final string = value[key];
  if (string == null) {
    return null;
  }
  if (string is! String || string.isEmpty || string.length > 4096) {
    throw FormatException('$key must be null or a bounded nonempty string.');
  }
  return string;
}

String _rawProcessDetails({
  _CapturedOutput? stderr,
  int? exitCode,
  String? helperStage,
  int? nativeError,
  String? nativeCode,
  String? parserError,
}) => [
  if (exitCode != null) 'exitCode=$exitCode',
  if (helperStage != null) 'stage=$helperStage',
  if (nativeError != null) 'nativeError=$nativeError',
  if (nativeCode != null) 'nativeCode=$nativeCode',
  if (parserError != null) 'parserError=$parserError',
  if (stderr != null && stderr.text.trim().isNotEmpty)
    'stderr=${stderr.text.trim()}',
].join('; ');

bool _isAbsoluteWindowsPath(String path) {
  if (path.startsWith(r'\\?\') || path.startsWith(r'\\.\')) {
    return false;
  }
  return RegExp(
    r'^(?:[a-zA-Z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$))',
  ).hasMatch(path);
}

bool _sameWindowsPath(String left, String right) {
  String normalize(String value) {
    var normalized = value.replaceAll('/', r'\');
    while (normalized.length > 3 && normalized.endsWith(r'\')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.toLowerCase();
  }

  return normalize(left) == normalize(right);
}
