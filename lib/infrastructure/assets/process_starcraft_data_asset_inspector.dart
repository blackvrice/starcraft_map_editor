import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../application/ports/starcraft_data_asset_inspector.dart';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import 'starcraft_data_helper_protocol.dart';

final class ProcessStarCraftDataAssetInspector
    implements StarCraftDataAssetInspector {
  ProcessStarCraftDataAssetInspector({
    required this.helperExecutablePath,
    List<String> helperArguments = const [],
    this.timeout = const Duration(seconds: 15),
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
        'The helper executable path must be an absolute Windows path.',
      );
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }
    if (maximumProcessOutputBytes <= 0) {
      throw RangeError.value(
        maximumProcessOutputBytes,
        'maximumProcessOutputBytes',
        'Must be positive.',
      );
    }
    if (additionalInheritedEnvironmentKeys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError.value(
        additionalInheritedEnvironmentKeys,
        'additionalInheritedEnvironmentKeys',
        'Environment variable names must not be empty.',
      );
    }
  }

  factory ProcessStarCraftDataAssetInspector.bundled() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    return ProcessStarCraftDataAssetInspector(
      helperExecutablePath:
          '$executableDirectory${Platform.pathSeparator}'
          'starcraft_data_helper.exe',
    );
  }

  static const protocolVersion = StarCraftDataHelperProtocol.version;
  static const helperVersion = StarCraftDataHelperProtocol.helperVersion;
  static const cascLibRevision = StarCraftDataHelperProtocol.cascLibRevision;
  static const maximumTotalAssetBytes = 256 * 1024 * 1024;

  final String helperExecutablePath;
  final List<String> helperArguments;
  final Duration timeout;
  final int maximumProcessOutputBytes;
  final List<String> additionalInheritedEnvironmentKeys;
  final Map<String, String> parentEnvironment;

  int _requestSequence = 0;

  @override
  Future<StarCraftDataAssetInspection> inspect(String installationPath) async {
    if (!_isAbsoluteWindowsPath(installationPath) ||
        installationPath.trim() != installationPath) {
      return _failedInspection(
        installationPath: installationPath,
        diagnostic: _diagnostic(
          code: StarCraftDataAssetDiagnosticCodes.installationPathInvalid,
          message:
              'The StarCraft installation path must be an absolute Windows '
              'drive or UNC directory.',
          filePath: installationPath,
          remediation:
              'Choose the StarCraft installation using the Settings dialog.',
        ),
      );
    }

    if (!await File(helperExecutablePath).exists()) {
      return _failedInspection(
        installationPath: installationPath,
        diagnostic: _diagnostic(
          code: StarCraftDataAssetDiagnosticCodes.helperNotFound,
          message: 'The bundled StarCraft CASC helper is missing.',
          filePath: helperExecutablePath,
          remediation: 'Repair or reinstall the application.',
        ),
      );
    }

    final requestId =
        'starcraft-data-${DateTime.now().microsecondsSinceEpoch}-'
        '${_requestSequence++}';
    Process? process;
    Directory? temporaryDirectory;
    try {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_casc_',
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
          'operation': 'inspectInstallation',
          'installationPath': installationPath,
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
        return _failedInspection(
          installationPath: installationPath,
          diagnostic: _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.helperTimedOut,
            message: 'The StarCraft CASC inspection timed out.',
            filePath: installationPath,
            remediation:
                'Retry after repairing the StarCraft installation in '
                'Battle.net.',
            rawDetails: _rawProcessDetails(stderr: stderr),
          ),
        );
      }

      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      if (stdout.exceededLimit || stderr.exceededLimit) {
        return _failedInspection(
          installationPath: installationPath,
          diagnostic: _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.helperOutputLimitExceeded,
            message: 'The StarCraft CASC helper produced too much output.',
            filePath: installationPath,
            remediation: 'Repair the application or report the helper error.',
            rawDetails: _rawProcessDetails(exitCode: exitCode, stderr: stderr),
          ),
        );
      }

      return _parseResponse(
        stdout: stdout.text,
        stderr: stderr,
        exitCode: exitCode,
        requestId: requestId,
        installationPath: installationPath,
      );
    } on ProcessException catch (error) {
      return _failedInspection(
        installationPath: installationPath,
        diagnostic: _diagnostic(
          code: StarCraftDataAssetDiagnosticCodes.helperStartFailed,
          message: 'The StarCraft CASC helper could not be started.',
          filePath: helperExecutablePath,
          remediation: 'Repair or reinstall the application.',
          rawDetails: error.errorCode.toString(),
        ),
      );
    } on FileSystemException catch (error) {
      return _failedInspection(
        installationPath: installationPath,
        diagnostic: _diagnostic(
          code: StarCraftDataAssetDiagnosticCodes.inspectionFailed,
          message: 'The StarCraft installation could not be inspected.',
          filePath: error.path ?? installationPath,
          remediation: 'Check directory permissions and retry.',
          rawDetails: error.toString(),
        ),
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

  StarCraftDataAssetInspection _parseResponse({
    required String stdout,
    required _CapturedOutput stderr,
    required int exitCode,
    required String requestId,
    required String installationPath,
  }) {
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
          decoded,
          stderr: stderr,
          exitCode: exitCode,
          installationPath: installationPath,
        );
      }
      if (status != 'success' || exitCode != 0) {
        throw FormatException(
          'Unexpected helper status or exit code: $status/$exitCode.',
        );
      }

      final installation = _jsonObject(decoded, 'installation');
      final assets = _jsonObject(decoded, 'assets');
      final responsePath = _jsonString(installation, 'path');
      if (!_sameWindowsPath(responsePath, installationPath)) {
        throw const FormatException(
          'Helper response installation path does not match the request.',
        );
      }

      final requiredCount = _jsonInteger(assets, 'requiredCount');
      final foundCount = _jsonInteger(assets, 'foundCount');
      final totalBytes = _jsonInteger(assets, 'totalBytes');
      if (requiredCount !=
              StarCraftDataAssetManifest.requiredTilesetAssets.length ||
          foundCount < 0 ||
          foundCount > requiredCount ||
          totalBytes < 0 ||
          totalBytes > maximumTotalAssetBytes) {
        throw const FormatException('Helper returned invalid asset counts.');
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
        throw const FormatException(
          'Helper returned invalid CASC storage metadata.',
        );
      }

      final missingPaths = _jsonStringList(assets, 'missingPaths');
      final invalidAssets = assets['invalidAssets'];
      if (invalidAssets is! List) {
        throw const FormatException('invalidAssets must be a JSON array.');
      }
      final invalidPaths = <String>[];
      final invalidDetails = <String>[];
      for (final value in invalidAssets) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException(
            'Each invalid asset must be a JSON object.',
          );
        }
        final path = _jsonString(value, 'path');
        final nativeError = _jsonInteger(value, 'nativeError');
        invalidPaths.add(path);
        invalidDetails.add('$path: nativeError=$nativeError');
      }

      _validateAssetPaths(
        foundCount: foundCount,
        missingPaths: missingPaths,
        invalidPaths: invalidPaths,
      );
      final diagnostics = <EditorDiagnostic>[
        if (missingPaths.isNotEmpty)
          _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.filesMissing,
            message:
                '${missingPaths.length} required StarCraft CASC tileset '
                '${missingPaths.length == 1 ? 'asset is' : 'assets are'} '
                'missing.',
            filePath: installationPath,
            remediation:
                'Repair the StarCraft installation in Battle.net and retry.',
            rawDetails: missingPaths.join('\n'),
          ),
        if (invalidPaths.isNotEmpty)
          _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.filesInvalid,
            message:
                '${invalidPaths.length} required StarCraft CASC tileset '
                '${invalidPaths.length == 1 ? 'asset is' : 'assets are'} '
                'unreadable.',
            filePath: installationPath,
            remediation:
                'Repair the StarCraft installation in Battle.net and retry.',
            rawDetails: invalidDetails.join('\n'),
          ),
      ];

      return StarCraftDataAssetInspection(
        installationPath: installationPath,
        requiredAssetCount: requiredCount,
        foundAssetCount: foundCount,
        storageProduct: storageProduct,
        storageBuildNumber: storageBuildNumber,
        helperVersion: helperVersion,
        cascLibRevision: cascLibRevision,
        totalAssetBytes: totalBytes,
        missingRelativePaths: missingPaths,
        invalidRelativePaths: invalidPaths,
        diagnostics: diagnostics,
      );
    } on FormatException catch (error) {
      return _failedInspection(
        installationPath: installationPath,
        diagnostic: _diagnostic(
          code: StarCraftDataAssetDiagnosticCodes.helperInvalidResponse,
          message: 'The StarCraft CASC helper returned an invalid response.',
          filePath: installationPath,
          remediation: 'Repair the application or report the helper error.',
          rawDetails: _rawProcessDetails(
            exitCode: exitCode,
            stderr: stderr,
            parserError: error.message,
          ),
        ),
      );
    }
  }

  void _expectBaseResponse(Map<String, dynamic> response, String requestId) {
    if (_jsonInteger(response, 'protocolVersion') != protocolVersion ||
        _jsonString(response, 'requestId') != requestId ||
        _jsonString(response, 'operation') != 'inspectInstallation' ||
        _jsonString(response, 'helperVersion') != helperVersion ||
        _jsonString(response, 'cascLibRevision') != cascLibRevision) {
      throw const FormatException(
        'Helper protocol, request, or version metadata does not match.',
      );
    }
  }

  StarCraftDataAssetInspection _parseErrorResponse(
    Map<String, dynamic> response, {
    required _CapturedOutput stderr,
    required int exitCode,
    required String installationPath,
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
    return _failedInspection(
      installationPath: installationPath,
      diagnostic: _diagnostic(
        code: code,
        message: message,
        filePath: installationPath,
        remediation: _remediationFor(code),
        rawDetails: _rawProcessDetails(
          exitCode: exitCode,
          stderr: stderr,
          helperStage: stage,
          nativeError: nativeError,
        ),
      ),
    );
  }

  void _validateAssetPaths({
    required int foundCount,
    required List<String> missingPaths,
    required List<String> invalidPaths,
  }) {
    final expected = {
      for (final requirement
          in StarCraftDataAssetManifest.requiredTilesetAssets)
        requirement.relativePath,
    };
    final reported = [...missingPaths, ...invalidPaths];
    if (reported.toSet().length != reported.length ||
        reported.any((path) => !expected.contains(path)) ||
        foundCount + reported.length != expected.length) {
      throw const FormatException(
        'Helper asset paths do not cover the required manifest.',
      );
    }
  }

  Future<_CapturedOutput> _captureOutput(Stream<List<int>> stream) async {
    final bytes = <int>[];
    var exceededLimit = false;
    await for (final chunk in stream) {
      final available = maximumProcessOutputBytes - bytes.length;
      if (available <= 0) {
        exceededLimit = true;
        continue;
      }
      if (chunk.length > available) {
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
      // The process was already force-killed. Do not block the UI indefinitely.
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
  StarCraftDataAssetDiagnosticCodes.installationNotFound,
  StarCraftDataAssetDiagnosticCodes.installationNotDirectory,
  StarCraftDataAssetDiagnosticCodes.storageOpenFailed,
  StarCraftDataAssetDiagnosticCodes.storageInfoFailed,
};

final class _CapturedOutput {
  const _CapturedOutput({required this.text, required this.exceededLimit});

  final String text;
  final bool exceededLimit;
}

StarCraftDataAssetInspection _failedInspection({
  required String installationPath,
  required EditorDiagnostic diagnostic,
}) {
  return StarCraftDataAssetInspection(
    installationPath: installationPath,
    requiredAssetCount: StarCraftDataAssetManifest.requiredTilesetAssets.length,
    foundAssetCount: 0,
    missingRelativePaths: [
      for (final requirement
          in StarCraftDataAssetManifest.requiredTilesetAssets)
        requirement.relativePath,
    ],
    diagnostics: [diagnostic],
  );
}

EditorDiagnostic _diagnostic({
  required String code,
  required String message,
  required String filePath,
  required String remediation,
  String? rawDetails,
}) {
  return EditorDiagnostic(
    code: code,
    message: message,
    severity: DiagnosticSeverity.warning,
    stage: DiagnosticStage.validate,
    filePath: filePath,
    remediation: remediation,
    rawDetails: rawDetails,
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

List<String> _jsonStringList(Map<String, dynamic> value, String key) {
  final list = value[key];
  if (list is! List) {
    throw FormatException('$key must be a JSON array.');
  }
  return [
    for (final item in list)
      if (item is String && item.isNotEmpty && item.length <= 4096)
        item
      else
        throw FormatException('$key contains an invalid string.'),
  ];
}

String _remediationFor(String code) {
  return switch (code) {
    StarCraftDataAssetDiagnosticCodes.installationNotFound ||
    StarCraftDataAssetDiagnosticCodes.installationNotDirectory ||
    StarCraftDataAssetDiagnosticCodes.installationPathInvalid =>
      'Choose the StarCraft installation folder again.',
    StarCraftDataAssetDiagnosticCodes.storageOpenFailed ||
    StarCraftDataAssetDiagnosticCodes.storageInfoFailed =>
      'Repair the StarCraft installation in Battle.net and retry.',
    _ => 'Repair the application or report the StarCraft CASC helper error.',
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
