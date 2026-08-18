import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../application/ports/starcraft_object_atlas_gateway.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import 'starcraft_data_helper_protocol.dart';

final class ProcessStarCraftObjectAtlasGateway
    implements StarCraftObjectAtlasGateway {
  ProcessStarCraftObjectAtlasGateway({
    required this.helperExecutablePath,
    List<String> helperArguments = const [],
    this.timeout = const Duration(seconds: 30),
    this.maximumProcessOutputBytes = 256 * 1024,
    this.maximumAtlasFileBytes = maximumAllowedAtlasFileBytes,
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
        maximumAtlasFileBytes < atlasHeaderBytes ||
        maximumAtlasFileBytes > maximumAllowedAtlasFileBytes) {
      throw ArgumentError('Timeout and byte limits must be positive.');
    }
  }

  factory ProcessStarCraftObjectAtlasGateway.bundled() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    return ProcessStarCraftObjectAtlasGateway(
      helperExecutablePath:
          '$executableDirectory${Platform.pathSeparator}'
          'starcraft_data_helper.exe',
    );
  }

  static const protocolVersion = StarCraftDataHelperProtocol.version;
  static const helperVersion = StarCraftDataHelperProtocol.helperVersion;
  static const cascLibRevision = StarCraftDataHelperProtocol.cascLibRevision;
  static const atlasFileName = 'object-atlas.rgba';
  static const atlasFormatVersion = 1;
  static const atlasHeaderBytes = 32;
  static const atlasEntryBytes = 32;
  static const maximumAllowedAtlasFileBytes = 32 * 1024 * 1024;
  static const maximumTotalAssetBytes = 256 * 1024 * 1024;
  static const _operation = 'renderObjectAtlas';
  static const _atlasMagic = [0x53, 0x43, 0x4f, 0x52, 0x47, 0x42, 0x41, 0x00];

  final String helperExecutablePath;
  final List<String> helperArguments;
  final Duration timeout;
  final int maximumProcessOutputBytes;
  final int maximumAtlasFileBytes;
  final Map<String, String> parentEnvironment;
  final List<String> additionalInheritedEnvironmentKeys;

  final Map<String, Process> _activeProcesses = {};
  final Set<String> _reservedOperations = {};
  final Set<String> _cancelledOperations = {};

  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async {
    if (!_isAbsoluteWindowsPath(request.installationPath) ||
        request.installationPath.trim() != request.installationPath) {
      return _failure(
        request,
        code: StarCraftObjectAtlasDiagnosticCodes.installationPathInvalid,
        message: 'The StarCraft installation path is invalid.',
        filePath: request.installationPath,
        remediation: 'Choose the StarCraft installation folder again.',
      );
    }
    if (_reservedOperations.contains(request.operationId)) {
      return _failure(
        request,
        code: StarCraftObjectAtlasDiagnosticCodes.renderFailed,
        message: 'An object rendering operation with this ID is active.',
        filePath: request.installationPath,
        remediation: 'Wait for the current map rendering operation to finish.',
      );
    }
    _reservedOperations.add(request.operationId);

    Process? process;
    Directory? temporaryDirectory;
    try {
      if (!await File(helperExecutablePath).exists()) {
        return _failure(
          request,
          code: StarCraftObjectAtlasDiagnosticCodes.helperNotFound,
          message: 'The bundled StarCraft CASC helper is missing.',
          filePath: helperExecutablePath,
          remediation: 'Repair or reinstall the application.',
        );
      }
      if (_cancelledOperations.contains(request.operationId)) {
        return _cancelledFailure(request);
      }
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_objects_',
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
          'tileset': request.tileset.rawValue,
          'outputFileName': atlasFileName,
          'framePolicy': 'firstFrame',
          'objects': [
            for (final key in request.objects)
              {
                'kind': key.kind.wireName,
                'id': key.id,
                'playerColor': key.playerColor,
                'direction': key.direction,
              },
          ],
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
          code: StarCraftObjectAtlasDiagnosticCodes.helperTimedOut,
          message: 'The StarCraft object rendering helper timed out.',
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
          code: StarCraftObjectAtlasDiagnosticCodes.helperOutputLimitExceeded,
          message: 'The StarCraft object helper produced too much output.',
          filePath: request.installationPath,
          remediation: 'Repair the application or report the helper error.',
          rawDetails: _rawProcessDetails(exitCode: exitCode, stderr: stderr),
        );
      }
      return await _parseResponse(
        request: request,
        stdout: stdout.text,
        stderr: stderr,
        exitCode: exitCode,
        temporaryDirectory: temporaryDirectory,
      );
    } on ProcessException catch (error) {
      if (_cancelledOperations.remove(request.operationId)) {
        return _cancelledFailure(request);
      }
      return _failure(
        request,
        code: StarCraftObjectAtlasDiagnosticCodes.helperStartFailed,
        message: 'The StarCraft object helper could not be started.',
        filePath: helperExecutablePath,
        remediation: 'Repair or reinstall the application.',
        rawDetails: error.errorCode.toString(),
      );
    } on FileSystemException catch (error) {
      if (_cancelledOperations.remove(request.operationId)) {
        return _cancelledFailure(request);
      }
      return _failure(
        request,
        code: StarCraftObjectAtlasDiagnosticCodes.renderFailed,
        message: 'The StarCraft object atlas could not be read safely.',
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

  Future<StarCraftObjectAtlasResult> _parseResponse({
    required StarCraftObjectAtlasRequest request,
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
        throw const FormatException('Helper stdout must contain one response.');
      }
      final decoded = jsonDecode(lines.single);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Helper response must be a JSON object.');
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
        throw const FormatException('Unexpected helper status or exit code.');
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
          storageBuildNumber > 0xffffffff) {
        throw const FormatException('Invalid CASC storage metadata.');
      }
      if (_jsonInteger(decoded, 'tileset') != request.tileset.rawValue) {
        throw const FormatException('Helper returned a different tileset.');
      }

      final assets = _jsonObject(decoded, 'assets');
      final readCount = _jsonInteger(assets, 'readCount');
      final totalAssetBytes = _jsonInteger(assets, 'totalBytes');
      if (readCount < 7 ||
          readCount > 7 + request.objects.length ||
          totalAssetBytes <= 0 ||
          totalAssetBytes > maximumTotalAssetBytes) {
        throw const FormatException('Invalid object asset metadata.');
      }

      final atlas = _jsonObject(decoded, 'atlas');
      final fileName = _jsonString(atlas, 'fileName');
      final fileBytes = _jsonInteger(atlas, 'fileBytes');
      final formatVersion = _jsonInteger(atlas, 'formatVersion');
      final entryCount = _jsonInteger(atlas, 'entryCount');
      if (fileName != atlasFileName ||
          fileBytes < atlasHeaderBytes ||
          fileBytes > maximumAtlasFileBytes ||
          formatVersion != atlasFormatVersion ||
          entryCount < 0 ||
          entryCount > request.objects.length ||
          _jsonInteger(atlas, 'tileset') != request.tileset.rawValue) {
        throw const FormatException('Invalid object atlas metadata.');
      }
      final unsupported = _parseUnsupported(decoded);

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
        throw const FormatException('Object atlas output is inconsistent.');
      }
      final entries = _parseEnvelope(await outputFile.readAsBytes());
      if (entries.length != entryCount) {
        throw const FormatException('Object atlas entry count does not match.');
      }
      try {
        return StarCraftObjectAtlasResult(
          request: request,
          entries: entries,
          unsupportedObjects: unsupported,
          storageProduct: storageProduct,
          storageBuildNumber: storageBuildNumber,
          helperVersion: helperVersion,
          cascLibRevision: cascLibRevision,
          totalAssetBytes: totalAssetBytes,
        );
      } on ArgumentError catch (error) {
        throw FormatException('Object coverage is invalid: $error');
      }
    } on FormatException catch (error) {
      return _failure(
        request,
        code: StarCraftObjectAtlasDiagnosticCodes.helperInvalidResponse,
        message: 'The StarCraft object helper returned an invalid response.',
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

  List<StarCraftObjectAtlasEntry> _parseEnvelope(Uint8List bytes) {
    if (bytes.length < atlasHeaderBytes ||
        bytes.length > maximumAtlasFileBytes) {
      throw const FormatException('Object atlas envelope is truncated.');
    }
    for (var index = 0; index < _atlasMagic.length; index++) {
      if (bytes[index] != _atlasMagic[index]) {
        throw const FormatException('Object atlas magic is invalid.');
      }
    }
    final data = ByteData.sublistView(bytes);
    final formatVersion = data.getUint16(8, Endian.little);
    final entrySize = data.getUint16(10, Endian.little);
    final entryCount = data.getUint32(12, Endian.little);
    final tableBytes = data.getUint32(16, Endian.little);
    final pixelBytes = data.getUint32(20, Endian.little);
    if (formatVersion != atlasFormatVersion ||
        entrySize != atlasEntryBytes ||
        entryCount > StarCraftObjectAtlasRequest.maximumObjects ||
        tableBytes != entryCount * atlasEntryBytes ||
        data.getUint32(24, Endian.little) != 0 ||
        data.getUint32(28, Endian.little) != 0 ||
        atlasHeaderBytes + tableBytes + pixelBytes != bytes.length) {
      throw const FormatException('Object atlas fields are inconsistent.');
    }

    final entries = <StarCraftObjectAtlasEntry>[];
    var expectedPixelOffset = 0;
    for (var index = 0; index < entryCount; index++) {
      final offset = atlasHeaderBytes + index * atlasEntryBytes;
      final kindValue = data.getUint8(offset);
      final playerValue = data.getUint8(offset + 1);
      final direction = data.getUint8(offset + 2);
      final reservedByte = data.getUint8(offset + 3);
      final objectId = data.getUint16(offset + 4, Endian.little);
      final spriteId = data.getUint16(offset + 6, Endian.little);
      final imageId = data.getUint16(offset + 8, Endian.little);
      final width = data.getUint16(offset + 10, Endian.little);
      final height = data.getUint16(offset + 12, Endian.little);
      final anchorX = data.getInt16(offset + 14, Endian.little);
      final anchorY = data.getInt16(offset + 16, Endian.little);
      final frameIndex = data.getUint16(offset + 18, Endian.little);
      final pixelOffset = data.getUint32(offset + 20, Endian.little);
      final entryPixelBytes = data.getUint32(offset + 24, Endian.little);
      final reserved = data.getUint32(offset + 28, Endian.little);
      if (kindValue > 1 ||
          (playerValue > 7 && playerValue != 0xff) ||
          direction != 0 ||
          reservedByte != 0 ||
          reserved != 0 ||
          frameIndex != 0 ||
          width == 0 ||
          width > StarCraftObjectAtlasEntry.maximumDimension ||
          height == 0 ||
          height > StarCraftObjectAtlasEntry.maximumDimension ||
          entryPixelBytes != width * height * 4 ||
          entryPixelBytes > StarCraftObjectAtlasEntry.maximumFrameBytes ||
          pixelOffset != expectedPixelOffset ||
          pixelOffset + entryPixelBytes > pixelBytes) {
        throw const FormatException('Object atlas entry is inconsistent.');
      }
      final start = atlasHeaderBytes + tableBytes + pixelOffset;
      final key = StarCraftObjectGraphicKey(
        kind: StarCraftObjectGraphicKind.values[kindValue],
        id: objectId,
        playerColor: playerValue == 0xff ? null : playerValue,
        direction: direction,
      );
      try {
        entries.add(
          StarCraftObjectAtlasEntry(
            key: key,
            spriteId: spriteId,
            imageId: imageId,
            width: width,
            height: height,
            anchorX: anchorX,
            anchorY: anchorY,
            frameIndex: frameIndex,
            rgbaBytes: Uint8List.fromList(
              bytes.sublist(start, start + entryPixelBytes),
            ),
          ),
        );
      } on ArgumentError catch (error) {
        throw FormatException('Invalid object atlas entry: $error');
      }
      expectedPixelOffset += entryPixelBytes;
    }
    if (expectedPixelOffset != pixelBytes) {
      throw const FormatException('Object atlas pixel region has a gap.');
    }
    return entries;
  }

  List<StarCraftUnsupportedObjectGraphic> _parseUnsupported(
    Map<String, dynamic> response,
  ) {
    final values = response['unsupportedObjects'];
    if (values is! List) {
      throw const FormatException('unsupportedObjects must be an array.');
    }
    final unsupported = <StarCraftUnsupportedObjectGraphic>[];
    for (final value in values) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Unsupported object must be an object.');
      }
      final code = _jsonString(value, 'code');
      if (!code.startsWith('SC_CASC_OBJECT_') || code.length > 128) {
        throw const FormatException('Unsupported object code is invalid.');
      }
      unsupported.add(
        StarCraftUnsupportedObjectGraphic(key: _parseKey(value), code: code),
      );
    }
    return unsupported;
  }

  StarCraftObjectGraphicKey _parseKey(Map<String, dynamic> value) {
    final kindName = _jsonString(value, 'kind');
    final kind = switch (kindName) {
      'unit' => StarCraftObjectGraphicKind.unit,
      'sprite' => StarCraftObjectGraphicKind.sprite,
      _ => throw const FormatException('Object kind is invalid.'),
    };
    final id = _jsonInteger(value, 'id');
    final direction = _jsonInteger(value, 'direction');
    final playerValue = value['playerColor'];
    if (id < 0 ||
        id > 0xffff ||
        direction != 0 ||
        (playerValue != null &&
            (playerValue is! int || playerValue < 0 || playerValue > 7))) {
      throw const FormatException('Object key is invalid.');
    }
    return StarCraftObjectGraphicKey(
      kind: kind,
      id: id,
      playerColor: playerValue as int?,
      direction: direction,
    );
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

  StarCraftObjectAtlasResult _parseErrorResponse(
    StarCraftObjectAtlasRequest request,
    Map<String, dynamic> response, {
    required _CapturedOutput stderr,
    required int exitCode,
  }) {
    if (exitCode == 0) {
      throw const FormatException('Helper error cannot exit successfully.');
    }
    final error = _jsonObject(response, 'error');
    final code = _jsonString(error, 'code');
    final nativeError = _jsonInteger(error, 'nativeError');
    if (!_helperErrorCodes.contains(code) ||
        nativeError < 0 ||
        nativeError > 0xffffffff) {
      throw const FormatException('Helper returned an unknown error.');
    }
    return _failure(
      request,
      code: code,
      message: _jsonString(error, 'message'),
      filePath: request.installationPath,
      remediation: _remediationFor(code),
      rawDetails: _rawProcessDetails(
        exitCode: exitCode,
        stderr: stderr,
        helperStage: _jsonString(error, 'stage'),
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
  'SC_CASC_STORAGE_OPEN_FAILED',
  'SC_CASC_STORAGE_INFO_FAILED',
  'SC_CASC_OBJECT_METADATA_MISSING',
  'SC_CASC_OBJECT_METADATA_INVALID',
  'SC_CASC_OBJECT_PALETTE_MISSING',
  'SC_CASC_OBJECT_PALETTE_INVALID',
  'SC_CASC_OBJECT_ASSETS_TOO_LARGE',
  'SC_CASC_OBJECT_ATLAS_OUTPUT_EXISTS',
  'SC_CASC_OBJECT_ATLAS_OUTPUT_CREATE_FAILED',
  'SC_CASC_OBJECT_ATLAS_OUTPUT_WRITE_FAILED',
  'SC_CASC_OBJECT_ATLAS_OUTPUT_PROMOTE_FAILED',
  'SC_CASC_OBJECT_ATLAS_OUTPUT_TOO_LARGE',
  'SC_CASC_OBJECT_ATLAS_OUTPUT_INVALID',
};

final class _CapturedOutput {
  const _CapturedOutput({required this.text, required this.exceededLimit});

  final String text;
  final bool exceededLimit;
}

StarCraftObjectAtlasResult _cancelledFailure(
  StarCraftObjectAtlasRequest request, {
  String? rawDetails,
}) {
  return _failure(
    request,
    code: StarCraftObjectAtlasDiagnosticCodes.helperCancelled,
    message: 'The StarCraft object rendering operation was cancelled.',
    filePath: request.installationPath,
    remediation: 'Retry after the visible map state becomes stable.',
    rawDetails: rawDetails,
  );
}

StarCraftObjectAtlasResult _failure(
  StarCraftObjectAtlasRequest request, {
  required String code,
  required String message,
  required String filePath,
  required String remediation,
  String? rawDetails,
}) {
  return StarCraftObjectAtlasResult.failed(
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

String _remediationFor(String code) {
  return switch (code) {
    'SC_CASC_INSTALLATION_NOT_FOUND' || 'SC_CASC_INSTALLATION_NOT_DIRECTORY' =>
      'Choose the StarCraft installation folder again.',
    'SC_CASC_STORAGE_OPEN_FAILED' ||
    'SC_CASC_STORAGE_INFO_FAILED' ||
    'SC_CASC_OBJECT_METADATA_MISSING' ||
    'SC_CASC_OBJECT_METADATA_INVALID' ||
    'SC_CASC_OBJECT_PALETTE_MISSING' ||
    'SC_CASC_OBJECT_PALETTE_INVALID' =>
      'Repair the StarCraft installation in Battle.net and retry.',
    _ => 'Repair the application or report the object rendering error.',
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
