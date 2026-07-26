import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../application/ports/map_archive_gateway.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class MapArchiveDiagnosticCodes {
  static const helperNotFound = 'ARCHIVE_HELPER_NOT_FOUND';
  static const invalidSourcePath = 'ARCHIVE_SOURCE_PATH_NOT_ABSOLUTE';
  static const duplicateOperation = 'ARCHIVE_OPERATION_ALREADY_ACTIVE';
  static const startFailed = 'ARCHIVE_HELPER_START_FAILED';
  static const timedOut = 'ARCHIVE_OPERATION_TIMED_OUT';
  static const cancelled = 'ARCHIVE_OPERATION_CANCELLED';
  static const outputLimitExceeded = 'ARCHIVE_HELPER_OUTPUT_LIMIT_EXCEEDED';
  static const invalidResponse = 'ARCHIVE_HELPER_INVALID_RESPONSE';
  static const scenarioTooLarge = 'ARCHIVE_SCENARIO_TOO_LARGE';
  static const scenarioReadFailed = 'ARCHIVE_SCENARIO_READ_FAILED';
  static const temporaryDirectoryFailed = 'ARCHIVE_TEMP_DIRECTORY_FAILED';
  static const writeNotImplemented = 'ARCHIVE_WRITE_NOT_IMPLEMENTED';
}

class ProcessMapArchiveGateway implements MapArchiveGateway {
  ProcessMapArchiveGateway({
    required String helperExecutablePath,
    List<String> helperArguments = const [],
    this.temporaryRoot,
    this.maximumScenarioBytes = 64 * 1024 * 1024,
    this.maximumProcessOutputBytes = 1024 * 1024,
  }) : helperExecutablePath = helperExecutablePath,
       helperArguments = List.unmodifiable(helperArguments) {
    if (!_isAbsoluteWindowsPath(helperExecutablePath)) {
      throw ArgumentError.value(
        helperExecutablePath,
        'helperExecutablePath',
        'The helper executable path must be an absolute Windows path.',
      );
    }
    if (maximumScenarioBytes <= 0) {
      throw RangeError.value(
        maximumScenarioBytes,
        'maximumScenarioBytes',
        'The maximum scenario size must be positive.',
      );
    }
    if (maximumProcessOutputBytes <= 0) {
      throw RangeError.value(
        maximumProcessOutputBytes,
        'maximumProcessOutputBytes',
        'The maximum process output size must be positive.',
      );
    }
  }

  factory ProcessMapArchiveGateway.bundled() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    return ProcessMapArchiveGateway(
      helperExecutablePath:
          '$executableDirectory${Platform.pathSeparator}map_archive_helper.exe',
    );
  }

  static const protocolVersion = 1;
  static const helperVersion = '0.1.0';
  static const stormLibRevision = 'c91595a1a1b7b515567bd62a60af066914a29a6a';

  final String helperExecutablePath;
  final List<String> helperArguments;
  final Directory? temporaryRoot;
  final int maximumScenarioBytes;
  final int maximumProcessOutputBytes;
  final Map<String, Process> _activeProcesses = {};
  final Set<String> _cancelledOperationIds = {};

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    if (!_isAbsoluteWindowsPath(request.sourcePath)) {
      return _openFailure(
        code: MapArchiveDiagnosticCodes.invalidSourcePath,
        message: 'The map path must be an absolute Windows path.',
        filePath: request.sourcePath,
        remediation: 'Choose the map again using the Open Map dialog.',
      );
    }
    if (_activeProcesses.containsKey(request.operationId)) {
      return _openFailure(
        code: MapArchiveDiagnosticCodes.duplicateOperation,
        message: 'An archive operation with the same ID is already active.',
        filePath: request.sourcePath,
        remediation: 'Wait for the active operation or cancel it first.',
      );
    }

    final helperFile = File(helperExecutablePath);
    if (!await helperFile.exists()) {
      return _openFailure(
        code: MapArchiveDiagnosticCodes.helperNotFound,
        message: 'The bundled map archive helper is missing.',
        filePath: request.sourcePath,
        remediation: 'Repair or reinstall the application.',
      );
    }

    final Directory temporaryDirectory;
    try {
      temporaryDirectory = await (temporaryRoot ?? Directory.systemTemp)
          .createTemp('starcraft_map_editor_archive_');
    } on FileSystemException catch (error) {
      return _openFailure(
        code: MapArchiveDiagnosticCodes.temporaryDirectoryFailed,
        message: 'A temporary archive workspace could not be created.',
        filePath: request.sourcePath,
        remediation: 'Check free disk space and temporary folder permissions.',
        rawDetails: error.osError?.errorCode.toString(),
      );
    }

    final scenarioOutputPath =
        '${temporaryDirectory.path}${Platform.pathSeparator}scenario.chk';
    Process? process;
    try {
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

      final stdoutFuture = _captureOutput(
        process.stdout,
        maximumProcessOutputBytes,
      );
      final stderrFuture = _captureOutput(
        process.stderr,
        maximumProcessOutputBytes,
      );

      process.stdin.write(
        jsonEncode({
          'protocolVersion': protocolVersion,
          'requestId': request.operationId,
          'operation': 'extractScenario',
          'sourcePath': request.sourcePath,
          'scenarioOutputPath': scenarioOutputPath,
        }),
      );
      await process.stdin.close();

      final int exitCode;
      try {
        exitCode = await process.exitCode.timeout(request.timeout);
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        final terminated = await _waitForTermination(process);
        final stderr = terminated
            ? await stderrFuture
            : const _CapturedOutput(text: '', exceededLimit: false);
        if (terminated) {
          await stdoutFuture;
        }
        return _openFailure(
          code: MapArchiveDiagnosticCodes.timedOut,
          message: 'The map archive helper timed out.',
          filePath: request.sourcePath,
          remediation: 'Retry the operation or inspect the map for corruption.',
          rawDetails: _rawProcessDetails(
            stderr: stderr,
            processTerminated: terminated,
          ),
        );
      }

      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      if (_cancelledOperationIds.remove(request.operationId)) {
        return _openFailure(
          code: MapArchiveDiagnosticCodes.cancelled,
          message: 'The map archive operation was cancelled.',
          filePath: request.sourcePath,
          remediation: 'Open the map again when ready.',
          rawDetails: _rawProcessDetails(exitCode: exitCode, stderr: stderr),
        );
      }
      if (stdout.exceededLimit || stderr.exceededLimit) {
        return _openFailure(
          code: MapArchiveDiagnosticCodes.outputLimitExceeded,
          message: 'The map archive helper produced too much output.',
          filePath: request.sourcePath,
          remediation: 'Repair the application or report the helper failure.',
          rawDetails: _rawProcessDetails(exitCode: exitCode, stderr: stderr),
        );
      }

      final response = _parseResponse(
        stdout.text,
        request.operationId,
        exitCode,
      );
      if (response.error != null) {
        return _openFailure(
          code: response.error!.code,
          message: response.error!.message,
          filePath: request.sourcePath,
          remediation: _remediationFor(response.error!.code),
          rawDetails: _rawProcessDetails(
            exitCode: exitCode,
            helperStage: response.error!.stage,
            nativeError: response.error!.nativeError,
            stderr: stderr,
          ),
        );
      }

      final success = response.success!;
      if (success.uncompressedSizeBytes > maximumScenarioBytes) {
        return _openFailure(
          code: MapArchiveDiagnosticCodes.scenarioTooLarge,
          message: 'scenario.chk exceeds the configured extraction size limit.',
          filePath: request.sourcePath,
          remediation: 'Raise the reviewed size limit only for a trusted map.',
          rawDetails:
              'scenarioBytes=${success.uncompressedSizeBytes}; '
              'maximumBytes=$maximumScenarioBytes',
        );
      }

      final Uint8List scenarioBytes;
      try {
        scenarioBytes = await File(scenarioOutputPath).readAsBytes();
      } on FileSystemException catch (error) {
        return _openFailure(
          code: MapArchiveDiagnosticCodes.scenarioReadFailed,
          message: 'The extracted scenario.chk could not be read.',
          filePath: request.sourcePath,
          remediation: 'Retry the operation and check temporary disk access.',
          rawDetails: error.osError?.errorCode.toString(),
        );
      }

      if (scenarioBytes.length != success.uncompressedSizeBytes) {
        return _openFailure(
          code: MapArchiveDiagnosticCodes.invalidResponse,
          message: 'The extracted scenario.chk does not match helper metadata.',
          filePath: request.sourcePath,
          remediation: 'Repair the application or report the helper failure.',
          rawDetails:
              'actualBytes=${scenarioBytes.length}; '
              'reportedBytes=${success.uncompressedSizeBytes}',
        );
      }

      return MapArchiveOpenResult.success(
        map: ExtractedMap(
          sourcePath: request.sourcePath,
          scenarioChkBytes: scenarioBytes,
          metadata: MapArchiveMetadata(
            archiveSizeBytes: success.archiveSizeBytes,
            totalEntryCount: success.totalEntryCount,
            entries: [
              MapArchiveEntryMetadata(
                path: MapArchiveEntryPaths.scenarioChk,
                uncompressedSizeBytes: success.uncompressedSizeBytes,
                compressedSizeBytes: success.compressedSizeBytes,
              ),
            ],
          ),
        ),
      );
    } on ProcessException catch (error) {
      return _openFailure(
        code: MapArchiveDiagnosticCodes.startFailed,
        message: 'The map archive helper could not be started.',
        filePath: request.sourcePath,
        remediation: 'Repair or reinstall the application.',
        rawDetails: error.errorCode.toString(),
      );
    } on FormatException catch (error) {
      return _openFailure(
        code: MapArchiveDiagnosticCodes.invalidResponse,
        message: 'The map archive helper returned an invalid response.',
        filePath: request.sourcePath,
        remediation: 'Repair the application or report the helper failure.',
        rawDetails: error.message,
      );
    } finally {
      final activeProcess = _activeProcesses[request.operationId];
      if (activeProcess == process) {
        _activeProcesses.remove(request.operationId);
      }
      _cancelledOperationIds.remove(request.operationId);
      try {
        await temporaryDirectory.delete(recursive: true);
      } on FileSystemException {
        // Never widen cleanup beyond this exact app-created directory.
      }
    }
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) async {
    return MapArchiveWriteResult.failure(
      diagnostics: [
        EditorDiagnostic(
          code: MapArchiveDiagnosticCodes.writeNotImplemented,
          message: 'Temporary MPQ writing is not implemented yet.',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.save,
          filePath: request.sourcePath,
          remediation: 'Open maps read-only until Save As is implemented.',
        ),
      ],
    );
  }

  @override
  Future<bool> cancel(String operationId) async {
    final process = _activeProcesses[operationId];
    if (process == null) {
      return false;
    }

    _cancelledOperationIds.add(operationId);
    final killed = process.kill(ProcessSignal.sigkill);
    if (!killed) {
      _cancelledOperationIds.remove(operationId);
    }
    return killed;
  }

  MapArchiveOpenResult _openFailure({
    required String code,
    required String message,
    required String filePath,
    required String remediation,
    String? rawDetails,
  }) {
    return MapArchiveOpenResult.failure(
      diagnostics: [
        EditorDiagnostic(
          code: code,
          message: message,
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.archive,
          filePath: filePath,
          remediation: remediation,
          rawDetails: rawDetails,
        ),
      ],
    );
  }

  _ArchiveHelperResponse _parseResponse(
    String output,
    String operationId,
    int exitCode,
  ) {
    final lines = const LineSplitter()
        .convert(output)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length != 1) {
      throw const FormatException(
        'Expected exactly one nonempty helper response line.',
      );
    }

    final decoded = jsonDecode(lines.single);
    if (decoded is! Map<String, dynamic> ||
        decoded['protocolVersion'] != protocolVersion ||
        decoded['requestId'] != operationId ||
        decoded['operation'] != 'extractScenario' ||
        decoded['helperVersion'] != helperVersion ||
        decoded['stormLibRevision'] != stormLibRevision) {
      throw const FormatException(
        'The helper response identity or version does not match.',
      );
    }

    final status = decoded['status'];
    if (status == 'error') {
      if (exitCode == 0) {
        throw const FormatException(
          'An error response cannot use a successful exit code.',
        );
      }
      final error = decoded['error'];
      if (error is! Map<String, dynamic>) {
        throw const FormatException('The helper error payload is missing.');
      }
      final code = error['code'];
      final message = error['message'];
      final stage = error['stage'];
      final nativeError = error['nativeError'];
      if (code is! String ||
          code.isEmpty ||
          message is! String ||
          message.isEmpty ||
          stage is! String ||
          nativeError is! int ||
          nativeError < 0) {
        throw const FormatException('The helper error payload is invalid.');
      }
      return _ArchiveHelperResponse.error(
        _ArchiveHelperError(
          code: code,
          message: message,
          stage: stage,
          nativeError: nativeError,
        ),
      );
    }

    if (status != 'success' || exitCode != 0) {
      throw const FormatException(
        'The helper status and exit code are inconsistent.',
      );
    }
    final archive = decoded['archive'];
    final scenario = decoded['scenario'];
    if (archive is! Map<String, dynamic> ||
        scenario is! Map<String, dynamic> ||
        scenario['archivePath'] != MapArchiveEntryPaths.scenarioChk) {
      throw const FormatException('The helper success payload is missing.');
    }

    final archiveSizeBytes = archive['sizeBytes'];
    final totalEntryCount = archive['totalEntryCount'];
    final uncompressedSizeBytes = scenario['uncompressedSizeBytes'];
    final compressedSizeBytes = scenario['compressedSizeBytes'];
    if (archiveSizeBytes is! int ||
        archiveSizeBytes < 0 ||
        totalEntryCount is! int ||
        totalEntryCount < 1 ||
        uncompressedSizeBytes is! int ||
        uncompressedSizeBytes < 0 ||
        compressedSizeBytes is! int ||
        compressedSizeBytes < 0) {
      throw const FormatException('The helper metadata values are invalid.');
    }

    return _ArchiveHelperResponse.success(
      _ArchiveHelperSuccess(
        archiveSizeBytes: archiveSizeBytes,
        totalEntryCount: totalEntryCount,
        uncompressedSizeBytes: uncompressedSizeBytes,
        compressedSizeBytes: compressedSizeBytes,
      ),
    );
  }

  Map<String, String> _minimalEnvironment(String temporaryPath) {
    final environment = <String, String>{
      'TEMP': temporaryPath,
      'TMP': temporaryPath,
    };
    final systemRoot = Platform.environment['SystemRoot'];
    if (systemRoot != null && systemRoot.isNotEmpty) {
      environment['SystemRoot'] = systemRoot;
    }
    return environment;
  }

  String _rawProcessDetails({
    int? exitCode,
    String? helperStage,
    int? nativeError,
    _CapturedOutput? stderr,
    bool? processTerminated,
  }) {
    final fields = <String>[
      if (exitCode != null) 'exitCode=$exitCode',
      if (helperStage != null) 'helperStage=$helperStage',
      if (nativeError != null) 'nativeError=$nativeError',
      if (processTerminated != null) 'processTerminated=$processTerminated',
      if (stderr != null && stderr.text.isNotEmpty)
        'stderr=${_truncate(stderr.text.trim(), 4096)}',
      if (stderr?.exceededLimit ?? false) 'stderrTruncated=true',
    ];
    return fields.join('; ');
  }

  String _remediationFor(String code) {
    return switch (code) {
      'ARCHIVE_SCENARIO_NOT_FOUND' =>
        'Choose an unprotected StarCraft map containing scenario.chk.',
      'ARCHIVE_OPEN_FAILED' =>
        'Choose an intact, unprotected .scm or .scx map.',
      _ => 'Retry the operation or inspect the map for corruption.',
    };
  }
}

class _ArchiveHelperResponse {
  const _ArchiveHelperResponse.success(this.success) : error = null;

  const _ArchiveHelperResponse.error(this.error) : success = null;

  final _ArchiveHelperSuccess? success;
  final _ArchiveHelperError? error;
}

class _ArchiveHelperSuccess {
  const _ArchiveHelperSuccess({
    required this.archiveSizeBytes,
    required this.totalEntryCount,
    required this.uncompressedSizeBytes,
    required this.compressedSizeBytes,
  });

  final int archiveSizeBytes;
  final int totalEntryCount;
  final int uncompressedSizeBytes;
  final int compressedSizeBytes;
}

class _ArchiveHelperError {
  const _ArchiveHelperError({
    required this.code,
    required this.message,
    required this.stage,
    required this.nativeError,
  });

  final String code;
  final String message;
  final String stage;
  final int nativeError;
}

class _CapturedOutput {
  const _CapturedOutput({required this.text, required this.exceededLimit});

  final String text;
  final bool exceededLimit;
}

Future<_CapturedOutput> _captureOutput(
  Stream<List<int>> stream,
  int maximumBytes,
) async {
  final bytes = BytesBuilder(copy: false);
  var exceededLimit = false;
  await for (final chunk in stream) {
    final remaining = maximumBytes - bytes.length;
    if (remaining <= 0) {
      exceededLimit = true;
      continue;
    }
    if (chunk.length > remaining) {
      bytes.add(chunk.sublist(0, remaining));
      exceededLimit = true;
      continue;
    }
    bytes.add(chunk);
  }

  return _CapturedOutput(
    text: utf8.decode(bytes.takeBytes(), allowMalformed: true),
    exceededLimit: exceededLimit,
  );
}

Future<bool> _waitForTermination(Process process) async {
  try {
    await process.exitCode.timeout(const Duration(seconds: 5));
    return true;
  } on TimeoutException {
    return false;
  }
}

bool _isAbsoluteWindowsPath(String path) {
  return RegExp(
    r'^(?:[a-zA-Z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$))',
  ).hasMatch(path);
}

String _truncate(String value, int maximumLength) {
  if (value.length <= maximumLength) {
    return value;
  }
  return '${value.substring(0, maximumLength)}…';
}
