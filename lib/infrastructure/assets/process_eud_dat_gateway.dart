import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../application/ports/eud_dat_gateway.dart';
import 'starcraft_data_helper_protocol.dart';
import 'eud_dat_snapshot_decoder.dart';

final class ProcessEudDatGateway implements EudDatGateway {
  ProcessEudDatGateway({
    required this.helperExecutablePath,
    List<String> helperArguments = const [],
    this.timeout = const Duration(seconds: 30),
    this.maximumOutputBytes = 2 * 1024 * 1024,
    Map<String, String>? environment,
  }) : helperArguments = List.unmodifiable(helperArguments),
       environment = Map.unmodifiable(
         environment ??
             {
               if (Platform.environment['SystemRoot'] case final String root)
                 'SystemRoot': root,
             },
       ) {
    if (!_absolute(helperExecutablePath) ||
        timeout <= Duration.zero ||
        maximumOutputBytes <= 0) {
      throw ArgumentError('Absolute helper path and positive limits required.');
    }
  }

  factory ProcessEudDatGateway.bundled() => ProcessEudDatGateway(
    helperExecutablePath:
        '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}starcraft_data_helper.exe',
  );

  final String helperExecutablePath;
  final List<String> helperArguments;
  final Duration timeout;
  final int maximumOutputBytes;
  final Map<String, String> environment;
  final _active = <String, _ReadOperation>{};

  @override
  void cancel(String operationId) =>
      _active[operationId]?.stop('SC_EUD_DAT_CANCELLED');

  @override
  Future<EudDatReadResult> read({
    required String operationId,
    required String installationPath,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(operationId) ||
        !_absolute(installationPath)) {
      return const EudDatReadResult(errorCode: 'SC_EUD_DAT_REQUEST_INVALID');
    }
    if (_active.containsKey(operationId)) {
      return const EudDatReadResult(errorCode: 'SC_EUD_DAT_OPERATION_ACTIVE');
    }
    final op = _ReadOperation(maximumOutputBytes);
    _active[operationId] = op;
    Directory? directory;
    final timer = Timer(timeout, () => op.stop('SC_EUD_DAT_TIMED_OUT'));
    try {
      directory = await Directory.systemTemp.createTemp('sc_eud_dat_');
      if (op.error != null) return op.result();
      op.process = await Process.start(
        helperExecutablePath,
        helperArguments,
        workingDirectory: directory.path,
        includeParentEnvironment: false,
        environment: {
          ...environment,
          'TEMP': directory.path,
          'TMP': directory.path,
        },
        runInShell: false,
      );
      if (op.error != null) {
        op.process!.kill();
        return op.result();
      }
      final stdoutDone = op.capture(op.process!.stdout, op.stdoutBytes);
      final stderrDone = op.capture(op.process!.stderr, op.stderrBytes);
      final completed = () async {
        op.process!.stdin.writeln(
          jsonEncode({
            'protocolVersion': StarCraftDataHelperProtocol.version,
            'requestId': operationId,
            'operation': 'readEudDat',
            'installationPath': installationPath,
          }),
        );
        await op.process!.stdin.close();
        op.exit = await op.process!.exitCode;
        await Future.wait([stdoutDone, stderrDone]);
      }();
      await Future.any([completed, op.stopped.future]);
      if (op.error != null) return op.result();
      if (op.exit != 0) {
        return op.result(error: 'SC_EUD_DAT_HELPER_FAILED');
      }
      final json = jsonDecode(utf8.decode(op.stdoutBytes));
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Expected EUD DAT response object.');
      }
      final source = decodeEudDat(json, operationId, installationPath);
      return op.result(source: source);
    } on FormatException {
      return op.result(error: 'SC_EUD_DAT_RESPONSE_INVALID');
    } on ProcessException {
      return op.result(error: 'SC_EUD_DAT_HELPER_START_FAILED');
    } on IOException {
      return op.result(error: 'SC_EUD_DAT_IO_FAILED');
    } finally {
      timer.cancel();
      op.process?.kill();
      if (op.process != null) {
        try {
          await op.process!.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          // Never wait indefinitely for a failed helper to terminate.
        }
      }
      for (final subscription in op.subscriptions) {
        await subscription.cancel();
      }
      _active.remove(operationId);
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } on FileSystemException {
          // Only this app-created directory may be removed.
        }
      }
    }
  }
}

bool _absolute(String path) =>
    path.trim() == path &&
    !path.contains('\u0000') &&
    (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) ||
        RegExp(r'^\\\\[^\\/]+[\\/][^\\/]+').hasMatch(path));

class _ReadOperation {
  _ReadOperation(this.limit);
  final int limit;
  Process? process;
  String? error;
  int? exit;
  final stopped = Completer<void>();
  final stdoutBytes = <int>[], stderrBytes = <int>[];
  final subscriptions = <StreamSubscription<List<int>>>[];

  void stop(String code) {
    error ??= code;
    process?.kill();
    if (!stopped.isCompleted) stopped.complete();
  }

  Future<void> capture(Stream<List<int>> stream, List<int> bytes) {
    final done = Completer<void>();
    subscriptions.add(
      stream.listen(
        (chunk) {
          final room = limit - bytes.length;
          bytes.addAll(chunk.take(room));
          if (chunk.length > room) stop('SC_EUD_DAT_OUTPUT_LIMIT');
        },
        onError: (Object error) {
          stop('SC_EUD_DAT_IO_FAILED');
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    return done.future;
  }

  EudDatReadResult result({String? error, EudDatSource? source}) =>
      EudDatReadResult(
        source: source,
        errorCode: this.error ?? error,
        exitCode: exit,
        stdout: utf8.decode(stdoutBytes, allowMalformed: true),
        stderr: utf8.decode(stderrBytes, allowMalformed: true),
      );
}
