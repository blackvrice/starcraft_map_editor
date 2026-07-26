import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_record.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_diagnostic_parser.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/euddraft_diagnostic_parser.dart';

void main() {
  test('runs a prepared build and forwards its log events', () async {
    final progressController = OperationProgressController();
    final gateway = _ScriptedEudCompilerGateway((request) {
      return Stream.fromIterable([
        EudBuildEvent.started(
          buildId: request.buildId,
          toolVersion: request.tool.version,
        ),
        EudBuildEvent.stdoutLine(
          buildId: request.buildId,
          text: 'Compiling main.eps',
        ),
        EudBuildEvent.stderrLine(
          buildId: request.buildId,
          text: 'A recoverable warning',
        ),
        EudBuildEvent.finalizing(buildId: request.buildId),
        EudBuildEvent.succeeded(buildId: request.buildId, exitCode: 0),
      ]);
    });
    final controller = EudBuildController(
      buildGateway: gateway,
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progressController,
      clock: _SequenceClock([
        DateTime.utc(2026, 7, 26, 3),
        DateTime.utc(2026, 7, 26, 3, 0, 1),
        DateTime.utc(2026, 7, 26, 3, 0, 2),
        DateTime.utc(2026, 7, 26, 3, 0, 3),
      ]).call,
    );
    addTearDown(controller.dispose);
    addTearDown(progressController.dispose);

    expect(await controller.start(), isFalse);
    controller.prepare(_request('success-build'));

    expect(controller.state.status, EudBuildStatus.ready);
    expect(controller.canStart, isTrue);
    expect(await controller.start(), isTrue);

    expect(controller.state.status, EudBuildStatus.succeeded);
    expect(controller.state.events.map((event) => event.kind), [
      EudBuildEventKind.started,
      EudBuildEventKind.stdoutLine,
      EudBuildEventKind.stderrLine,
      EudBuildEventKind.finalizing,
      EudBuildEventKind.succeeded,
    ]);
    final record = controller.state.latestRecord!;
    expect(record.status, EudBuildRecordStatus.succeeded);
    expect(record.toolVersion, EudToolVersion.parse('0.10.2.5'));
    expect(record.startedAt, DateTime.utc(2026, 7, 26, 3));
    expect(record.completedAt, DateTime.utc(2026, 7, 26, 3, 0, 3));
    expect(record.exitCode, 0);
    expect(record.stdoutLines, ['Compiling main.eps']);
    expect(record.stderrLines, ['A recoverable warning']);
    expect(progressController.current?.phase, OperationPhase.succeeded);
  });

  test('surfaces a compiler failure as a terminal operation', () async {
    final progressController = OperationProgressController();
    final gateway = _ScriptedEudCompilerGateway((request) {
      return Stream.fromIterable([
        EudBuildEvent.failed(
          buildId: request.buildId,
          diagnostic: _blockingDiagnostic(
            code: 'EUD_TEST_COMPILE_FAILED',
            message: 'main.eps could not be compiled.',
          ),
          exitCode: 1,
        ),
      ]);
    });
    final controller = EudBuildController(
      buildGateway: gateway,
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progressController,
    );
    addTearDown(controller.dispose);
    addTearDown(progressController.dispose);
    controller.prepare(_request('failed-build'));

    expect(await controller.start(), isFalse);

    expect(controller.state.status, EudBuildStatus.failed);
    expect(controller.state.diagnostics.single.code, 'EUD_TEST_COMPILE_FAILED');
    expect(progressController.current?.phase, OperationPhase.failed);
    expect(progressController.current?.message, contains('could not'));
  });

  test('converts compiler stderr while preserving the raw log line', () async {
    final progressController = OperationProgressController();
    final gateway = _ScriptedEudCompilerGateway((request) {
      return Stream.fromIterable([
        EudBuildEvent.stderrLine(
          buildId: request.buildId,
          text:
              r'[Error 7041] Module "C:\Project\EUD Source\main.eps" '
              'Line 27 : Undefined function SpawnBoss',
        ),
        EudBuildEvent.failed(
          buildId: request.buildId,
          diagnostic: _blockingDiagnostic(
            code: 'EUD_BUILD_PROCESS_FAILED',
            message: 'euddraft exited with a failure code.',
          ),
          exitCode: 1,
        ),
      ]);
    });
    final controller = EudBuildController(
      buildGateway: gateway,
      diagnosticParser: const EuddraftDiagnosticParser(),
      operationProgressController: progressController,
      clock: _SequenceClock([
        DateTime.utc(2026, 7, 26, 4),
        DateTime.utc(2026, 7, 26, 4, 0, 1),
        DateTime.utc(2026, 7, 26, 4, 0, 2),
      ]).call,
    );
    addTearDown(controller.dispose);
    addTearDown(progressController.dispose);
    controller.prepare(_request('diagnostic-build'));

    expect(await controller.start(), isFalse);

    expect(controller.state.events.map((event) => event.kind), [
      EudBuildEventKind.stderrLine,
      EudBuildEventKind.diagnostic,
      EudBuildEventKind.failed,
    ]);
    final parsedDiagnostic = controller.state.diagnostics.first;
    expect(parsedDiagnostic.code, 'EUD_EPSCRIPT_ERROR_7041');
    expect(parsedDiagnostic.filePath, r'C:\Project\EUD Source\main.eps');
    expect(parsedDiagnostic.sourceLine, 27);
    final record = controller.state.latestRecord!;
    expect(record.stderrLines.single, contains('[Error 7041]'));
    expect(record.diagnostics.first, same(parsedDiagnostic));
    expect(record.diagnostics.last.code, 'EUD_BUILD_PROCESS_FAILED');
  });

  test('requests cancellation and waits for the cancelled event', () async {
    final progressController = OperationProgressController();
    final gateway = _CancellableEudCompilerGateway();
    final controller = EudBuildController(
      buildGateway: gateway,
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progressController,
    );
    addTearDown(controller.dispose);
    addTearDown(progressController.dispose);
    controller.prepare(_request('cancel-build'));

    final result = controller.start();
    gateway.emitStarted();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, EudBuildStatus.running);
    expect(await controller.cancel(), isTrue);
    expect(await result, isFalse);

    expect(gateway.cancelledBuildId, 'cancel-build');
    expect(controller.state.status, EudBuildStatus.cancelled);
    expect(progressController.current?.phase, OperationPhase.cancelled);
  });

  test('fails safely when the event stream closes without a result', () async {
    final progressController = OperationProgressController();
    final gateway = _ScriptedEudCompilerGateway((_) => const Stream.empty());
    final controller = EudBuildController(
      buildGateway: gateway,
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progressController,
    );
    addTearDown(controller.dispose);
    addTearDown(progressController.dispose);
    controller.prepare(_request('empty-build'));

    expect(await controller.start(), isFalse);

    expect(controller.state.status, EudBuildStatus.failed);
    expect(
      controller.state.diagnostics.single.code,
      EudBuildControllerDiagnosticCodes.eventStreamEnded,
    );
  });

  test('retains only the configured number of recent build records', () async {
    final progressController = OperationProgressController();
    final gateway = _ScriptedEudCompilerGateway((request) {
      return Stream.value(
        EudBuildEvent.succeeded(buildId: request.buildId, exitCode: 0),
      );
    });
    final controller = EudBuildController(
      buildGateway: gateway,
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progressController,
      maximumBuildRecords: 2,
    );
    addTearDown(controller.dispose);
    addTearDown(progressController.dispose);

    for (final buildId in ['first', 'second', 'third']) {
      controller.prepare(_request(buildId));
      expect(await controller.start(), isTrue);
    }

    expect(controller.state.records.map((record) => record.buildId), [
      'second',
      'third',
    ]);
    expect(() => controller.state.records.clear(), throwsUnsupportedError);
  });
}

EudBuildPlan _request(String buildId) {
  return EudBuildPlan(
    buildId: buildId,
    configuration: EudBuildConfiguration(
      baseMapPath: r'C:\Project\base\Base.scx',
      sourceRootPath: r'C:\Project\src',
      entrySourcePath: r'C:\Project\src\main.eps',
      outputMapPath: r'C:\Project\build\Output.scx',
    ),
    tool: _tool(),
    timeout: const Duration(minutes: 2),
  );
}

EudToolInfo _tool() {
  return EudToolInfo(
    pathSource: EudToolPathSource.projectProfile,
    installationPath: r'C:\Tools\euddraft',
    executablePath: r'C:\Tools\euddraft\euddraft.exe',
    versionFilePath: r'C:\Tools\euddraft\VERSION',
    version: EudToolVersion.parse('0.10.2.5'),
    companionPaths: const [r'C:\Tools\euddraft\python3.dll'],
  );
}

EditorDiagnostic _blockingDiagnostic({
  required String code,
  required String message,
}) {
  return EditorDiagnostic(
    code: code,
    message: message,
    severity: DiagnosticSeverity.error,
    stage: DiagnosticStage.compile,
    filePath: r'C:\Project\src\main.eps',
    remediation: 'Fix the epScript source and retry.',
  );
}

final class _ScriptedEudCompilerGateway implements EudBuildGateway {
  _ScriptedEudCompilerGateway(this.script);

  final Stream<EudBuildEvent> Function(EudBuildPlan request) script;

  @override
  Stream<EudBuildEvent> build(EudBuildPlan request) => script(request);

  @override
  Future<bool> cancel(String buildId) async => false;
}

final class _CancellableEudCompilerGateway implements EudBuildGateway {
  final StreamController<EudBuildEvent> _events =
      StreamController<EudBuildEvent>();

  EudBuildPlan? _request;
  String? cancelledBuildId;

  @override
  Stream<EudBuildEvent> build(EudBuildPlan request) {
    _request = request;
    return _events.stream;
  }

  void emitStarted() {
    final request = _request!;
    _events.add(
      EudBuildEvent.started(
        buildId: request.buildId,
        toolVersion: request.tool.version,
      ),
    );
  }

  @override
  Future<bool> cancel(String buildId) async {
    cancelledBuildId = buildId;
    _events.add(
      EudBuildEvent.cancelled(
        buildId: buildId,
        diagnostic: _blockingDiagnostic(
          code: 'EUD_TEST_CANCELLED',
          message: 'The test build was cancelled.',
        ),
      ),
    );
    await _events.close();
    return true;
  }
}

final class _SequenceClock {
  _SequenceClock(Iterable<DateTime> values) : _values = values.iterator;

  final Iterator<DateTime> _values;

  DateTime call() {
    if (!_values.moveNext()) {
      throw StateError('The test clock has no remaining values.');
    }
    return _values.current;
  }
}
