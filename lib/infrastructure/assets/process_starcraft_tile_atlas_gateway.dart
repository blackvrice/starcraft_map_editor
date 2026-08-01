import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../application/ports/starcraft_tile_atlas_gateway.dart';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import 'starcraft_data_helper_protocol.dart';

final class ProcessStarCraftTileAtlasGateway
    implements StarCraftTileAtlasGateway {
  ProcessStarCraftTileAtlasGateway({
    required this.helperExecutablePath,
    List<String> helperArguments = const [],
    this.timeout = const Duration(seconds: 30),
    this.maximumProcessOutputBytes = 256 * 1024,
    this.maximumAtlasFileBytes = 17 * 1024 * 1024,
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
        'The helper executable path must be an absolute Windows path.',
      );
    }
    if (timeout <= Duration.zero ||
        maximumProcessOutputBytes <= 0 ||
        maximumAtlasFileBytes <= 0 ||
        maximumAtlasFileBytes > maximumAllowedAtlasFileBytes) {
      throw ArgumentError('Timeout and byte limits must be positive.');
    }
  }

  factory ProcessStarCraftTileAtlasGateway.bundled() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    return ProcessStarCraftTileAtlasGateway(
      helperExecutablePath:
          '$executableDirectory${Platform.pathSeparator}'
          'starcraft_data_helper.exe',
    );
  }

  static const protocolVersion = StarCraftDataHelperProtocol.version;
  static const helperVersion = StarCraftDataHelperProtocol.helperVersion;
  static const cascLibRevision = StarCraftDataHelperProtocol.cascLibRevision;
  static const atlasFileName = 'tile-atlas.rgba';
  static const atlasFormatVersion = 1;
  static const atlasHeaderBytes = 32;
  static const maximumAllowedAtlasFileBytes = 17 * 1024 * 1024;
  static const maximumTotalAssetBytes = 256 * 1024 * 1024;
  static const _operation = 'renderTileAtlas';
  static const _atlasMagic = [0x53, 0x43, 0x54, 0x52, 0x47, 0x42, 0x41, 0x00];

  final String helperExecutablePath;
  final List<String> helperArguments;
  final Duration timeout;
  final int maximumProcessOutputBytes;
  final int maximumAtlasFileBytes;
  final Map<String, String> parentEnvironment;
  final List<String> additionalInheritedEnvironmentKeys;

  int _requestSequence = 0;

  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async {
    if (!_isAbsoluteWindowsPath(request.installationPath) ||
        request.installationPath.trim() != request.installationPath) {
      return _failure(
        request,
        code: StarCraftTileAtlasDiagnosticCodes.installationPathInvalid,
        message:
            'The StarCraft installation path must be an absolute Windows '
            'drive or UNC directory.',
        filePath: request.installationPath,
        remediation:
            'Choose the StarCraft installation using the Settings dialog.',
      );
    }
    if (!await File(helperExecutablePath).exists()) {
      return _failure(
        request,
        code: StarCraftTileAtlasDiagnosticCodes.helperNotFound,
        message: 'The bundled StarCraft CASC helper is missing.',
        filePath: helperExecutablePath,
        remediation: 'Repair or reinstall the application.',
      );
    }

    final requestId =
        'starcraft-atlas-${DateTime.now().microsecondsSinceEpoch}-'
        '${_requestSequence++}';
    Process? process;
    Directory? temporaryDirectory;
    try {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_atlas_',
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
      final stdoutFuture = _captureOutput(process.stdout);
      final stderrFuture = _captureOutput(process.stderr);
      process.stdin.writeln(
        jsonEncode({
          'protocolVersion': protocolVersion,
          'requestId': requestId,
          'operation': _operation,
          'installationPath': request.installationPath,
          'tileset': request.tileset.rawValue,
          'rawValues': request.rawValues,
          'outputFileName': atlasFileName,
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
          code: StarCraftTileAtlasDiagnosticCodes.helperTimedOut,
          message: 'The StarCraft tile rendering helper timed out.',
          filePath: request.installationPath,
          remediation:
              'Retry after repairing the StarCraft installation in Battle.net.',
          rawDetails: _rawProcessDetails(stderr: stderr),
        );
      }

      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      if (stdout.exceededLimit || stderr.exceededLimit) {
        return _failure(
          request,
          code: StarCraftTileAtlasDiagnosticCodes.helperOutputLimitExceeded,
          message: 'The StarCraft tile helper produced too much output.',
          filePath: request.installationPath,
          remediation: 'Repair the application or report the helper error.',
          rawDetails: _rawProcessDetails(exitCode: exitCode, stderr: stderr),
        );
      }
      return await _parseResponse(
        request: request,
        requestId: requestId,
        stdout: stdout.text,
        stderr: stderr,
        exitCode: exitCode,
        temporaryDirectory: temporaryDirectory,
      );
    } on ProcessException catch (error) {
      return _failure(
        request,
        code: StarCraftTileAtlasDiagnosticCodes.helperStartFailed,
        message: 'The StarCraft tile helper could not be started.',
        filePath: helperExecutablePath,
        remediation: 'Repair or reinstall the application.',
        rawDetails: error.errorCode.toString(),
      );
    } on FileSystemException catch (error) {
      return _failure(
        request,
        code: StarCraftTileAtlasDiagnosticCodes.renderFailed,
        message: 'The StarCraft tile atlas could not be read safely.',
        filePath: error.path ?? request.installationPath,
        remediation: 'Check directory permissions and retry.',
        rawDetails: error.toString(),
      );
    } finally {
      if (temporaryDirectory != null) {
        try {
          await temporaryDirectory.delete(recursive: true);
        } on FileSystemException {
          // Never widen cleanup beyond this exact app-created directory.
        }
      }
    }
  }

  Future<StarCraftTileAtlasResult> _parseResponse({
    required StarCraftTileAtlasRequest request,
    required String requestId,
    required String stdout,
    required _CapturedOutput stderr,
    required int exitCode,
    required Directory temporaryDirectory,
  }) async {
    try {
      final lines = const LineSplitter()
          .convert(stdout)
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.length != 1) {
        throw const FormatException(
          'Helper stdout must contain one JSON response.',
        );
      }
      final decoded = jsonDecode(lines.single);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Helper response must be a JSON object.');
      }
      _expectBaseResponse(decoded, requestId);
      final status = decoded['status'];
      if (status == 'error') {
        return _parseErrorResponse(
          request,
          decoded,
          stderr: stderr,
          exitCode: exitCode,
        );
      }
      if (status != 'success' || exitCode != 0) {
        throw FormatException(
          'Unexpected helper status or exit code: $status/$exitCode.',
        );
      }

      final installation = _jsonObject(decoded, 'installation');
      if (!_sameWindowsPath(
        _jsonString(installation, 'path'),
        request.installationPath,
      )) {
        throw const FormatException(
          'Helper response installation path does not match the request.',
        );
      }
      final storageProduct = _jsonString(installation, 'storageProduct');
      final storageBuildNumber = _jsonInteger(
        installation,
        'storageBuildNumber',
      );
      if (storageProduct.trim() != storageProduct ||
          storageProduct.length > 64 ||
          storageBuildNumber < 0 ||
          storageBuildNumber > 0xFFFFFFFF) {
        throw const FormatException('Invalid CASC storage metadata.');
      }
      if (_jsonInteger(decoded, 'tileset') != request.tileset.rawValue) {
        throw const FormatException('Helper returned a different tileset.');
      }

      final assets = _jsonObject(decoded, 'assets');
      final readCount = _jsonInteger(assets, 'readCount');
      final totalAssetBytes = _jsonInteger(assets, 'totalBytes');
      if (readCount != StarCraftDataAssetManifest.renderAssetKinds.length ||
          totalAssetBytes <= 0 ||
          totalAssetBytes > maximumTotalAssetBytes) {
        throw const FormatException('Invalid render asset metadata.');
      }

      final atlas = _jsonObject(decoded, 'atlas');
      final fileName = _jsonString(atlas, 'fileName');
      final fileBytes = _jsonInteger(atlas, 'fileBytes');
      final formatVersion = _jsonInteger(atlas, 'formatVersion');
      final tileSize = _jsonInteger(atlas, 'tileSize');
      final columns = _jsonInteger(atlas, 'columns');
      final rows = _jsonInteger(atlas, 'rows');
      final tileCount = _jsonInteger(atlas, 'tileCount');
      if (fileName != atlasFileName ||
          fileBytes < atlasHeaderBytes ||
          fileBytes > maximumAtlasFileBytes ||
          formatVersion != atlasFormatVersion ||
          tileSize != StarCraftTileAtlasResult.expectedTileSize ||
          columns < 0 ||
          rows < 0 ||
          tileCount < 0 ||
          tileCount > request.rawValues.length) {
        throw const FormatException('Invalid atlas response metadata.');
      }
      final unsupported = _jsonIntegerList(decoded, 'unsupportedRawValues');
      _expectStrictlyIncreasing(unsupported, 'unsupportedRawValues');

      final outputFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}$atlasFileName',
      );
      final outputType = await FileSystemEntity.type(
        outputFile.path,
        followLinks: false,
      );
      final stat = await outputFile.stat();
      if (outputType != FileSystemEntityType.file ||
          stat.type != FileSystemEntityType.file ||
          stat.size != fileBytes) {
        throw const FormatException(
          'Atlas output is missing or has a mismatched size.',
        );
      }
      final bytes = await outputFile.readAsBytes();
      final envelope = _parseEnvelope(bytes);
      if (envelope.tileSize != tileSize ||
          envelope.columns != columns ||
          envelope.rows != rows ||
          envelope.rawValues.length != tileCount) {
        throw const FormatException(
          'Atlas envelope does not match response metadata.',
        );
      }
      final covered = [...envelope.rawValues, ...unsupported]..sort();
      if (!_sameValues(covered, request.rawValues)) {
        throw const FormatException(
          'Rendered and unsupported values do not cover the request.',
        );
      }

      return StarCraftTileAtlasResult(
        request: request,
        tileSize: envelope.tileSize,
        columns: envelope.columns,
        rows: envelope.rows,
        rawValues: envelope.rawValues,
        rgbaBytes: envelope.rgbaBytes,
        unsupportedRawValues: unsupported,
        storageProduct: storageProduct,
        storageBuildNumber: storageBuildNumber,
        helperVersion: helperVersion,
        cascLibRevision: cascLibRevision,
        totalAssetBytes: totalAssetBytes,
      );
    } on FormatException catch (error) {
      return _failure(
        request,
        code: StarCraftTileAtlasDiagnosticCodes.helperInvalidResponse,
        message: 'The StarCraft tile helper returned an invalid response.',
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

  _AtlasEnvelope _parseEnvelope(Uint8List bytes) {
    if (bytes.length < atlasHeaderBytes) {
      throw const FormatException('Atlas envelope is truncated.');
    }
    for (var index = 0; index < _atlasMagic.length; index++) {
      if (bytes[index] != _atlasMagic[index]) {
        throw const FormatException('Atlas envelope magic is invalid.');
      }
    }
    final data = ByteData.sublistView(bytes);
    final formatVersion = data.getUint16(8, Endian.little);
    final tileSize = data.getUint16(10, Endian.little);
    final columns = data.getUint16(12, Endian.little);
    final rows = data.getUint16(14, Endian.little);
    final tileCount = data.getUint32(16, Endian.little);
    final entryBytes = data.getUint32(20, Endian.little);
    final pixelBytes = data.getUint32(24, Endian.little);
    final reserved = data.getUint32(28, Endian.little);
    final expectedPixelBytes =
        columns *
        rows *
        tileSize *
        tileSize *
        StarCraftTileAtlasResult.bytesPerPixel;
    if (formatVersion != atlasFormatVersion ||
        tileSize != StarCraftTileAtlasResult.expectedTileSize ||
        reserved != 0 ||
        entryBytes != tileCount * 4 ||
        pixelBytes != expectedPixelBytes ||
        atlasHeaderBytes + entryBytes + pixelBytes != bytes.length ||
        bytes.length > maximumAtlasFileBytes ||
        (tileCount == 0 && (columns != 0 || rows != 0 || pixelBytes != 0)) ||
        (tileCount > 0 &&
            (columns == 0 || rows == 0 || tileCount > columns * rows))) {
      throw const FormatException('Atlas envelope fields are inconsistent.');
    }
    final rawValues = <int>[];
    for (var index = 0; index < tileCount; index++) {
      final offset = atlasHeaderBytes + index * 4;
      rawValues.add(data.getUint16(offset, Endian.little));
      if (data.getUint16(offset + 2, Endian.little) != 0) {
        throw const FormatException('Atlas entry reserved bits are not zero.');
      }
    }
    _expectStrictlyIncreasing(rawValues, 'atlas rawValues');
    if (rawValues.any((value) => value >= 0x4000)) {
      throw const FormatException(
        'The atlas rendered a raw value outside the supported CV5 range.',
      );
    }
    final pixelOffset = atlasHeaderBytes + entryBytes;
    return _AtlasEnvelope(
      tileSize: tileSize,
      columns: columns,
      rows: rows,
      rawValues: rawValues,
      rgbaBytes: Uint8List.fromList(bytes.sublist(pixelOffset)),
    );
  }

  void _expectBaseResponse(Map<String, dynamic> response, String requestId) {
    if (_jsonInteger(response, 'protocolVersion') != protocolVersion ||
        _jsonString(response, 'requestId') != requestId ||
        _jsonString(response, 'operation') != _operation ||
        _jsonString(response, 'helperVersion') != helperVersion ||
        _jsonString(response, 'cascLibRevision') != cascLibRevision) {
      throw const FormatException(
        'Helper protocol, request, or version metadata does not match.',
      );
    }
  }

  StarCraftTileAtlasResult _parseErrorResponse(
    StarCraftTileAtlasRequest request,
    Map<String, dynamic> response, {
    required _CapturedOutput stderr,
    required int exitCode,
  }) {
    if (exitCode == 0) {
      throw const FormatException(
        'A helper error response cannot exit successfully.',
      );
    }
    final error = _jsonObject(response, 'error');
    final code = _jsonString(error, 'code');
    final message = _jsonString(error, 'message');
    final stage = _jsonString(error, 'stage');
    final nativeError = _jsonInteger(error, 'nativeError');
    if (!_helperErrorCodes.contains(code) ||
        nativeError < 0 ||
        nativeError > 0xFFFFFFFF) {
      throw const FormatException('Helper returned an unknown error.');
    }
    return _failure(
      request,
      code: code,
      message: message,
      filePath: request.installationPath,
      remediation: _remediationFor(code),
      rawDetails: _rawProcessDetails(
        exitCode: exitCode,
        stderr: stderr,
        helperStage: stage,
        nativeError: nativeError,
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
      // The process was already force-killed. Do not block indefinitely.
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
  StarCraftTileAtlasDiagnosticCodes.storageOpenFailed,
  StarCraftTileAtlasDiagnosticCodes.storageInfoFailed,
  StarCraftTileAtlasDiagnosticCodes.assetMissing,
  StarCraftTileAtlasDiagnosticCodes.assetInvalid,
  'SC_CASC_TILE_ATLAS_OUTPUT_EXISTS',
  'SC_CASC_TILE_ATLAS_OUTPUT_CREATE_FAILED',
  'SC_CASC_TILE_ATLAS_OUTPUT_WRITE_FAILED',
  'SC_CASC_TILE_ATLAS_OUTPUT_PROMOTE_FAILED',
  StarCraftTileAtlasDiagnosticCodes.atlasOutputInvalid,
};

final class _CapturedOutput {
  const _CapturedOutput({required this.text, required this.exceededLimit});

  final String text;
  final bool exceededLimit;
}

final class _AtlasEnvelope {
  const _AtlasEnvelope({
    required this.tileSize,
    required this.columns,
    required this.rows,
    required this.rawValues,
    required this.rgbaBytes,
  });

  final int tileSize;
  final int columns;
  final int rows;
  final List<int> rawValues;
  final Uint8List rgbaBytes;
}

StarCraftTileAtlasResult _failure(
  StarCraftTileAtlasRequest request, {
  required String code,
  required String message,
  required String filePath,
  required String remediation,
  String? rawDetails,
}) {
  return StarCraftTileAtlasResult.failed(
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
}

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
    throw FormatException('$key must be a nonempty bounded string.');
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

List<int> _jsonIntegerList(Map<String, dynamic> value, String key) {
  final list = value[key];
  if (list is! List) {
    throw FormatException('$key must be a JSON array.');
  }
  return [
    for (final item in list)
      if (item is int && item >= 0 && item <= 0xFFFF)
        item
      else
        throw FormatException('$key contains an invalid u16.'),
  ];
}

void _expectStrictlyIncreasing(List<int> values, String name) {
  var previous = -1;
  for (final value in values) {
    if (value <= previous) {
      throw FormatException('$name must be sorted and unique.');
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

String _remediationFor(String code) {
  return switch (code) {
    'SC_CASC_INSTALLATION_NOT_FOUND' ||
    'SC_CASC_INSTALLATION_NOT_DIRECTORY' ||
    StarCraftTileAtlasDiagnosticCodes.installationPathInvalid =>
      'Choose the StarCraft installation folder again.',
    StarCraftTileAtlasDiagnosticCodes.storageOpenFailed ||
    StarCraftTileAtlasDiagnosticCodes.storageInfoFailed ||
    StarCraftTileAtlasDiagnosticCodes.assetMissing ||
    StarCraftTileAtlasDiagnosticCodes.assetInvalid =>
      'Repair the StarCraft installation in Battle.net and retry.',
    _ => 'Repair the application or report the StarCraft tile helper error.',
  };
}

String _rawProcessDetails({
  _CapturedOutput? stderr,
  int? exitCode,
  String? helperStage,
  int? nativeError,
  String? parserError,
}) {
  return [
    if (exitCode != null) 'exitCode=$exitCode',
    if (helperStage != null) 'stage=$helperStage',
    if (nativeError != null) 'nativeError=$nativeError',
    if (parserError != null) 'parserError=$parserError',
    if (stderr != null && stderr.text.trim().isNotEmpty)
      'stderr=${stderr.text.trim()}',
  ].join('; ');
}

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
