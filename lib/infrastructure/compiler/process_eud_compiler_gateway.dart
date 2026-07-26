import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../application/ports/eud_compiler_gateway.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class EudCompilerDiagnosticCodes {
  static const platformUnsupported = 'EUD_BUILD_PLATFORM_UNSUPPORTED';
  static const duplicateBuild = 'EUD_BUILD_ALREADY_ACTIVE';
  static const executablePathInvalid = 'EUD_BUILD_EXECUTABLE_PATH_INVALID';
  static const executableMissing = 'EUD_BUILD_EXECUTABLE_MISSING';
  static const settingsPathInvalid = 'EUD_BUILD_SETTINGS_PATH_INVALID';
  static const settingsMissing = 'EUD_BUILD_SETTINGS_MISSING';
  static const startFailed = 'EUD_BUILD_START_FAILED';
  static const timedOut = 'EUD_BUILD_TIMED_OUT';
  static const cancelled = 'EUD_BUILD_CANCELLED';
  static const outputLimitExceeded = 'EUD_BUILD_OUTPUT_LIMIT_EXCEEDED';
  static const processFailed = 'EUD_BUILD_PROCESS_FAILED';
  static const unexpectedFailure = 'EUD_BUILD_UNEXPECTED_FAILURE';
}

final class ProcessEudCompilerGateway implements EudCompilerGateway {
  ProcessEudCompilerGateway({
    List<String> executableArgumentPrefix = const [],
    this.maximumProcessOutputBytes = 1024 * 1024,
    bool Function()? isWindows,
    Map<String, String>? parentEnvironment,
  }) : executableArgumentPrefix = List.unmodifiable(executableArgumentPrefix),
       _isWindows = isWindows ?? (() => Platform.isWindows),
       _parentEnvironment = Map.unmodifiable(
         parentEnvironment ?? Platform.environment,
       ) {
    if (maximumProcessOutputBytes <= 0) {
      throw RangeError.value(
        maximumProcessOutputBytes,
        'maximumProcessOutputBytes',
        'The maximum process output size must be positive.',
      );
    }
  }

  static const _inheritedEnvironmentNames = {
    'APPDATA',
    'COMSPEC',
    'HOMEDRIVE',
    'HOMEPATH',
    'LOCALAPPDATA',
    'PATH',
    'PATHEXT',
    'PROGRAMDATA',
    'PROGRAMFILES',
    'PROGRAMFILES(X86)',
    'PROGRAMW6432',
    'SYSTEMDRIVE',
    'SYSTEMROOT',
    'TEMP',
    'TMP',
    'USERPROFILE',
    'WINDIR',
  };

  final List<String> executableArgumentPrefix;
  final int maximumProcessOutputBytes;
  final bool Function() _isWindows;
  final Map<String, String> _parentEnvironment;
  final Map<String, Object> _activeBuildTokens = {};
  final Map<String, Process> _activeProcesses = {};
  final Set<String> _cancelledBuildIds = {};

  @override
  Stream<EudBuildEvent> build(EudBuildRequest request) {
    final buildToken = Object();
    late final StreamController<EudBuildEvent> controller;
    var started = false;
    controller = StreamController<EudBuildEvent>(
      onListen: () {
        if (started) {
          return;
        }
        started = true;
        unawaited(_runBuild(request, buildToken, controller));
      },
      onCancel: () async {
        await _cancelOwnedBuild(request.buildId, buildToken);
      },
    );
    return controller.stream;
  }

  @override
  Future<bool> cancel(String buildId) {
    return _cancelOwnedBuild(buildId, null);
  }

  Future<bool> _cancelOwnedBuild(String buildId, Object? expectedToken) async {
    final activeToken = _activeBuildTokens[buildId];
    if (activeToken == null ||
        (expectedToken != null && !identical(activeToken, expectedToken))) {
      return false;
    }

    _cancelledBuildIds.add(buildId);
    final process = _activeProcesses[buildId];
    if (process == null) {
      return true;
    }

    final killed = process.kill(ProcessSignal.sigkill);
    if (!killed) {
      _cancelledBuildIds.remove(buildId);
    }
    return killed;
  }

  Future<void> _runBuild(
    EudBuildRequest request,
    Object buildToken,
    StreamController<EudBuildEvent> controller,
  ) async {
    if (_activeBuildTokens.containsKey(request.buildId)) {
      _add(
        controller,
        _failed(
          request,
          code: EudCompilerDiagnosticCodes.duplicateBuild,
          message: 'An EUD build with the same ID is already active.',
          filePath: request.settingsFilePath,
          remediation: 'Wait for the active build or cancel it first.',
        ),
      );
      await controller.close();
      return;
    }
    _activeBuildTokens[request.buildId] = buildToken;

    Process? process;
    try {
      final validationFailure = await _validate(request);
      if (validationFailure != null) {
        _add(controller, validationFailure);
        return;
      }
      if (_cancelledBuildIds.contains(request.buildId)) {
        _add(controller, _cancelled(request));
        return;
      }

      final settingsFile = File(request.settingsFilePath).absolute;
      try {
        process = await Process.start(
          request.tool.executablePath,
          [...executableArgumentPrefix, settingsFile.path],
          workingDirectory: settingsFile.parent.path,
          environment: _buildEnvironment(request.environmentOverrides),
          includeParentEnvironment: false,
          runInShell: false,
          mode: ProcessStartMode.normal,
        );
      } on ProcessException catch (error) {
        _add(
          controller,
          _failed(
            request,
            code: EudCompilerDiagnosticCodes.startFailed,
            message: 'euddraft could not be started.',
            filePath: request.tool.executablePath,
            remediation: 'Reinspect the euddraft installation and retry.',
            rawDetails:
                'errorCode=${error.errorCode}; '
                'message=${error.message}',
          ),
        );
        return;
      }

      _activeProcesses[request.buildId] = process;
      final stdoutFuture = _forwardLines(
        stream: process.stdout,
        buildId: request.buildId,
        kind: EudBuildEventKind.stdoutLine,
        controller: controller,
      );
      final stderrFuture = _forwardLines(
        stream: process.stderr,
        buildId: request.buildId,
        kind: EudBuildEventKind.stderrLine,
        controller: controller,
      );

      _add(
        controller,
        EudBuildEvent.started(
          buildId: request.buildId,
          toolVersion: request.tool.version,
        ),
      );
      await process.stdin.close();

      if (_cancelledBuildIds.contains(request.buildId)) {
        process.kill(ProcessSignal.sigkill);
      }

      final int exitCode;
      try {
        exitCode = await process.exitCode.timeout(request.timeout);
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        final terminated = await _waitForTermination(process);
        if (terminated) {
          await Future.wait([stdoutFuture, stderrFuture]);
        }
        _add(
          controller,
          _failed(
            request,
            code: EudCompilerDiagnosticCodes.timedOut,
            message: 'The euddraft build timed out.',
            filePath: request.settingsFilePath,
            remediation: 'Inspect the build log, then retry or cancel.',
            rawDetails: 'processTerminated=$terminated',
          ),
        );
        return;
      }

      final outputResults = await Future.wait([stdoutFuture, stderrFuture]);
      if (_cancelledBuildIds.contains(request.buildId)) {
        _add(controller, _cancelled(request, exitCode: exitCode));
        return;
      }
      if (outputResults.any((result) => result.exceededLimit)) {
        _add(
          controller,
          _failed(
            request,
            code: EudCompilerDiagnosticCodes.outputLimitExceeded,
            message: 'euddraft produced more output than the safety limit.',
            filePath: request.settingsFilePath,
            remediation:
                'Inspect the source for runaway logging before retrying.',
            rawDetails:
                'exitCode=$exitCode; '
                'maximumBytesPerStream=$maximumProcessOutputBytes',
            exitCode: exitCode,
          ),
        );
        return;
      }
      if (exitCode != 0) {
        _add(
          controller,
          _failed(
            request,
            code: EudCompilerDiagnosticCodes.processFailed,
            message: 'euddraft exited with a failure code.',
            filePath: request.settingsFilePath,
            remediation: 'Review stdout and stderr for the compiler error.',
            rawDetails: 'exitCode=$exitCode',
            exitCode: exitCode,
          ),
        );
        return;
      }

      _add(
        controller,
        EudBuildEvent.succeeded(buildId: request.buildId, exitCode: exitCode),
      );
    } on FileSystemException catch (error) {
      _add(
        controller,
        _failed(
          request,
          code: EudCompilerDiagnosticCodes.unexpectedFailure,
          message: 'The EUD build could not access a required file.',
          filePath: error.path ?? request.settingsFilePath,
          remediation: 'Check file permissions and retry.',
          rawDetails: error.osError?.errorCode.toString(),
        ),
      );
    } on Object catch (error, stackTrace) {
      _add(
        controller,
        _failed(
          request,
          code: EudCompilerDiagnosticCodes.unexpectedFailure,
          message: 'The EUD build failed unexpectedly.',
          filePath: request.settingsFilePath,
          remediation: 'Retry the build or report the failure.',
          rawDetails: '$error\n$stackTrace',
        ),
      );
    } finally {
      final activeProcess = _activeProcesses[request.buildId];
      if (activeProcess == process) {
        _activeProcesses.remove(request.buildId);
      }
      if (identical(_activeBuildTokens[request.buildId], buildToken)) {
        _activeBuildTokens.remove(request.buildId);
        _cancelledBuildIds.remove(request.buildId);
      }
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  Future<EudBuildEvent?> _validate(EudBuildRequest request) async {
    if (!_isWindows()) {
      return _failed(
        request,
        code: EudCompilerDiagnosticCodes.platformUnsupported,
        message: 'euddraft builds are supported only on Windows.',
        filePath: request.tool.executablePath,
        remediation: 'Run the editor on Windows 10 or Windows 11.',
      );
    }
    if (!_isAbsoluteWindowsPath(request.tool.executablePath)) {
      return _failed(
        request,
        code: EudCompilerDiagnosticCodes.executablePathInvalid,
        message: 'The euddraft executable path must be absolute.',
        filePath: request.tool.executablePath,
        remediation: 'Inspect and select the euddraft installation again.',
      );
    }
    final executableType = await FileSystemEntity.type(
      request.tool.executablePath,
      followLinks: false,
    );
    if (executableType != FileSystemEntityType.file ||
        await File(request.tool.executablePath).length() == 0) {
      return _failed(
        request,
        code: EudCompilerDiagnosticCodes.executableMissing,
        message: 'The inspected euddraft executable is no longer available.',
        filePath: request.tool.executablePath,
        remediation: 'Inspect the euddraft installation again.',
      );
    }
    if (!_isAbsoluteWindowsPath(request.settingsFilePath) ||
        !request.settingsFilePath.toLowerCase().endsWith('.eds')) {
      return _failed(
        request,
        code: EudCompilerDiagnosticCodes.settingsPathInvalid,
        message: 'The euddraft settings path must be an absolute .eds path.',
        filePath: request.settingsFilePath,
        remediation: 'Choose a generated one-shot .eds settings file.',
      );
    }
    final settingsType = await FileSystemEntity.type(
      request.settingsFilePath,
      followLinks: false,
    );
    if (settingsType != FileSystemEntityType.file ||
        await File(request.settingsFilePath).length() == 0) {
      return _failed(
        request,
        code: EudCompilerDiagnosticCodes.settingsMissing,
        message: 'The euddraft settings file is missing or empty.',
        filePath: request.settingsFilePath,
        remediation: 'Generate the build settings again and retry.',
      );
    }
    return null;
  }

  Future<_ForwardOutputResult> _forwardLines({
    required Stream<List<int>> stream,
    required String buildId,
    required EudBuildEventKind kind,
    required StreamController<EudBuildEvent> controller,
  }) async {
    var capturedBytes = 0;
    var exceededLimit = false;
    final limitedStream = stream.transform<List<int>>(
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          final remaining = maximumProcessOutputBytes - capturedBytes;
          if (remaining <= 0) {
            exceededLimit = true;
            return;
          }
          if (chunk.length > remaining) {
            sink.add(chunk.sublist(0, remaining));
            capturedBytes += remaining;
            exceededLimit = true;
            return;
          }
          sink.add(chunk);
          capturedBytes += chunk.length;
        },
      ),
    );

    await for (final line
        in limitedStream
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())) {
      _add(
        controller,
        kind == EudBuildEventKind.stdoutLine
            ? EudBuildEvent.stdoutLine(buildId: buildId, text: line)
            : EudBuildEvent.stderrLine(buildId: buildId, text: line),
      );
    }
    return _ForwardOutputResult(exceededLimit: exceededLimit);
  }

  Map<String, String> _buildEnvironment(
    Map<String, String> environmentOverrides,
  ) {
    final environment = <String, String>{};
    for (final entry in _parentEnvironment.entries) {
      if (_inheritedEnvironmentNames.contains(entry.key.toUpperCase())) {
        environment[entry.key.toUpperCase()] = entry.value;
      }
    }
    for (final entry in environmentOverrides.entries) {
      environment[entry.key.toUpperCase()] = entry.value;
    }
    return environment;
  }

  EudBuildEvent _failed(
    EudBuildRequest request, {
    required String code,
    required String message,
    required String filePath,
    required String remediation,
    String? rawDetails,
    int? exitCode,
  }) {
    return EudBuildEvent.failed(
      buildId: request.buildId,
      diagnostic: EditorDiagnostic(
        code: code,
        message: message,
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.compile,
        filePath: filePath,
        remediation: remediation,
        rawDetails: rawDetails,
      ),
      exitCode: exitCode,
    );
  }

  EudBuildEvent _cancelled(EudBuildRequest request, {int? exitCode}) {
    return EudBuildEvent.cancelled(
      buildId: request.buildId,
      diagnostic: EditorDiagnostic(
        code: EudCompilerDiagnosticCodes.cancelled,
        message: 'The EUD build was cancelled.',
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.compile,
        filePath: request.settingsFilePath,
        remediation: 'Start the build again when ready.',
      ),
      exitCode: exitCode,
    );
  }

  void _add(StreamController<EudBuildEvent> controller, EudBuildEvent event) {
    if (!controller.isClosed) {
      controller.add(event);
    }
  }
}

final class _ForwardOutputResult {
  const _ForwardOutputResult({required this.exceededLimit});

  final bool exceededLimit;
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
