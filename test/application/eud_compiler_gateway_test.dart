import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  group('EudBuildRequest', () {
    test(
      'copies paths, environment, tool, and timeout into an immutable request',
      () {
        final environment = {'BUILD_MODE': 'test'};
        final request = EudBuildRequest(
          buildId: ' build-1 ',
          tool: _tool(),
          settingsFilePath: r' C:\Project\build.eds ',
          timeout: const Duration(seconds: 30),
          environmentOverrides: environment,
        );
        environment['BUILD_MODE'] = 'changed';

        expect(request.buildId, 'build-1');
        expect(request.settingsFilePath, r'C:\Project\build.eds');
        expect(request.tool.version.toString(), '0.10.2.5');
        expect(request.timeout, const Duration(seconds: 30));
        expect(request.environmentOverrides, {'BUILD_MODE': 'test'});
        expect(
          () => request.environmentOverrides['OTHER'] = 'value',
          throwsUnsupportedError,
        );
      },
    );

    test(
      'rejects blank IDs, nonpositive timeouts, and invalid environment',
      () {
        expect(
          () => EudBuildRequest(
            buildId: ' ',
            tool: _tool(),
            settingsFilePath: r'C:\Project\build.eds',
            timeout: const Duration(seconds: 1),
          ),
          throwsArgumentError,
        );
        expect(
          () => EudBuildRequest(
            buildId: 'build',
            tool: _tool(),
            settingsFilePath: r'C:\Project\build.eds',
            timeout: Duration.zero,
          ),
          throwsArgumentError,
        );
        expect(
          () => EudBuildRequest(
            buildId: 'build',
            tool: _tool(),
            settingsFilePath: r'C:\Project\build.eds',
            timeout: const Duration(seconds: 1),
            environmentOverrides: const {'BAD=NAME': 'value'},
          ),
          throwsArgumentError,
        );
        expect(
          () => EudBuildRequest(
            buildId: 'build',
            tool: _tool(),
            settingsFilePath: r'C:\Project\build.eds',
            timeout: const Duration(seconds: 1),
            environmentOverrides: const {'Path': 'first', 'PATH': 'second'},
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('EudBuildEvent', () {
    test('represents ordered logs and exactly typed terminal outcomes', () {
      final started = EudBuildEvent.started(
        buildId: 'build',
        toolVersion: EudToolVersion.parse('0.10.2.5'),
      );
      final stdout = EudBuildEvent.stdoutLine(buildId: 'build', text: 'line');
      final succeeded = EudBuildEvent.succeeded(buildId: 'build', exitCode: 0);

      expect(started.kind, EudBuildEventKind.started);
      expect(started.toolVersion.toString(), '0.10.2.5');
      expect(stdout.kind, EudBuildEventKind.stdoutLine);
      expect(stdout.text, 'line');
      expect(started.isTerminal, isFalse);
      expect(succeeded.isTerminal, isTrue);
      expect(
        () => EudBuildEvent.succeeded(buildId: 'build', exitCode: 1),
        throwsArgumentError,
      );
    });

    test('requires blocking diagnostics for failed terminal events', () {
      const warning = EditorDiagnostic(
        code: 'TEST_WARNING',
        message: 'warning',
        severity: DiagnosticSeverity.warning,
        stage: DiagnosticStage.compile,
      );

      expect(
        () => EudBuildEvent.failed(buildId: 'build', diagnostic: warning),
        throwsArgumentError,
      );
      expect(
        () => EudBuildEvent.cancelled(buildId: 'build', diagnostic: warning),
        throwsArgumentError,
      );
    });
  });

  test(
    'EudCompilerGateway supports a fake without process dependencies',
    () async {
      final gateway = _FakeEudCompilerGateway();
      final events = await gateway
          .build(
            EudBuildRequest(
              buildId: 'fake-build',
              tool: _tool(),
              settingsFilePath: r'C:\Project\build.eds',
              timeout: const Duration(seconds: 5),
            ),
          )
          .toList();

      expect(events.map((event) => event.kind), [
        EudBuildEventKind.started,
        EudBuildEventKind.succeeded,
      ]);
      expect(await gateway.cancel('fake-build'), isFalse);
    },
  );
}

EudToolInfo _tool() {
  return EudToolInfo(
    pathSource: EudToolPathSource.userSettings,
    installationPath: r'C:\Tools\euddraft',
    executablePath: r'C:\Tools\euddraft\euddraft.exe',
    versionFilePath: r'C:\Tools\euddraft\VERSION',
    version: EudToolVersion.parse('0.10.2.5'),
    companionPaths: const [r'C:\Tools\euddraft\python3.dll'],
  );
}

final class _FakeEudCompilerGateway implements EudCompilerGateway {
  @override
  Stream<EudBuildEvent> build(EudBuildRequest request) {
    return Stream.fromIterable([
      EudBuildEvent.started(
        buildId: request.buildId,
        toolVersion: request.tool.version,
      ),
      EudBuildEvent.succeeded(buildId: request.buildId, exitCode: 0),
    ]);
  }

  @override
  Future<bool> cancel(String buildId) async => false;
}
