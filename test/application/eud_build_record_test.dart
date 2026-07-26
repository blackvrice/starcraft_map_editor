import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_record.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  test('records ordered stdout and stderr with UTC timestamps', () {
    final startedAt = DateTime.parse('2026-07-26T12:00:00+09:00');
    final firstLogAt = startedAt.add(const Duration(seconds: 1));
    final secondLogAt = startedAt.add(const Duration(seconds: 2));
    final record =
        EudBuildRecord.running(
              buildId: 'record-build',
              toolVersion: EudToolVersion.parse('0.10.2.5'),
              startedAt: startedAt,
            )
            .appendLog(
              channel: EudBuildLogChannel.stdout,
              text: 'Compiling main.eps',
              capturedAt: firstLogAt,
            )
            .appendLog(
              channel: EudBuildLogChannel.stderr,
              text: 'Compiler warning',
              capturedAt: secondLogAt,
            );

    expect(record.startedAt, DateTime.parse('2026-07-26T03:00:00Z'));
    expect(record.logEntries.map((entry) => entry.channel), [
      EudBuildLogChannel.stdout,
      EudBuildLogChannel.stderr,
    ]);
    expect(record.logEntries.first.capturedAt, firstLogAt.toUtc());
    expect(record.stdoutLines, ['Compiling main.eps']);
    expect(record.stderrLines, ['Compiler warning']);
    expect(
      () => record.logEntries.add(
        EudBuildLogEntry(
          channel: EudBuildLogChannel.stdout,
          text: 'mutate',
          capturedAt: startedAt,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('completes a successful record with exit code and duration', () {
    final startedAt = DateTime.utc(2026, 7, 26, 3);
    final completedAt = startedAt.add(const Duration(seconds: 4));
    final record =
        EudBuildRecord.running(
          buildId: 'success-build',
          toolVersion: EudToolVersion.parse('0.10.2.5'),
          startedAt: startedAt,
        ).complete(
          status: EudBuildRecordStatus.succeeded,
          completedAt: completedAt,
          exitCode: 0,
        );

    expect(record.status, EudBuildRecordStatus.succeeded);
    expect(record.completedAt, completedAt);
    expect(record.exitCode, 0);
    expect(record.duration, const Duration(seconds: 4));
    expect(
      () => record.appendLog(
        channel: EudBuildLogChannel.stdout,
        text: 'late',
        capturedAt: completedAt,
      ),
      throwsStateError,
    );
  });

  test('preserves diagnostics and optional failure exit codes', () {
    const diagnostic = EditorDiagnostic(
      code: 'EUD_TEST_FAILED',
      message: 'The compiler failed.',
      severity: DiagnosticSeverity.error,
      stage: DiagnosticStage.compile,
    );
    final record =
        EudBuildRecord.running(
          buildId: 'failed-build',
          toolVersion: EudToolVersion.parse('0.10.2.5'),
          startedAt: DateTime.utc(2026, 7, 26, 3),
        ).complete(
          status: EudBuildRecordStatus.failed,
          completedAt: DateTime.utc(2026, 7, 26, 3, 0, 1),
          exitCode: 7,
          diagnostic: diagnostic,
        );

    expect(record.exitCode, 7);
    expect(record.diagnostics.single, same(diagnostic));
    expect(() => record.diagnostics.add(diagnostic), throwsUnsupportedError);
  });

  test('rejects invalid terminal record transitions', () {
    final startedAt = DateTime.utc(2026, 7, 26, 3);
    final record = EudBuildRecord.running(
      buildId: 'invalid-build',
      toolVersion: EudToolVersion.parse('0.10.2.5'),
      startedAt: startedAt,
    );

    expect(
      () => record.complete(
        status: EudBuildRecordStatus.running,
        completedAt: startedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => record.complete(
        status: EudBuildRecordStatus.succeeded,
        completedAt: startedAt,
        exitCode: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => record.complete(
        status: EudBuildRecordStatus.failed,
        completedAt: startedAt.subtract(const Duration(seconds: 1)),
      ),
      throwsArgumentError,
    );
  });
}
