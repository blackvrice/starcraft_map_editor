import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  group('EudToolInspectionRequest', () {
    test('uses project, user, and bundled paths in priority order', () {
      final project = const EudToolInspectionRequest(
        projectProfilePath: r'C:\Project\euddraft.exe',
        userSettingsPath: r'C:\User\euddraft.exe',
        bundledPath: r'C:\Bundle\euddraft.exe',
      ).selectedCandidate;
      final user = const EudToolInspectionRequest(
        projectProfilePath: ' ',
        userSettingsPath: r'C:\User\euddraft.exe',
        bundledPath: r'C:\Bundle\euddraft.exe',
      ).selectedCandidate;
      final bundled = const EudToolInspectionRequest(
        bundledPath: r'C:\Bundle\euddraft.exe',
      ).selectedCandidate;

      expect(project?.path, r'C:\Project\euddraft.exe');
      expect(project?.source, EudToolPathSource.projectProfile);
      expect(user?.path, r'C:\User\euddraft.exe');
      expect(user?.source, EudToolPathSource.userSettings);
      expect(bundled?.path, r'C:\Bundle\euddraft.exe');
      expect(bundled?.source, EudToolPathSource.bundled);
      expect(const EudToolInspectionRequest().selectedCandidate, isNull);
    });
  });

  group('EudToolVersion', () {
    test('parses and compares four-component versions', () {
      final version = EudToolVersion.parse(' 0.10.2.5 ');

      expect(version.toString(), '0.10.2.5');
      expect(version, EudToolVersion.parse('0.10.2.5'));
      expect(version.compareTo(EudToolVersion.parse('0.10.3.0')), lessThan(0));
      expect(EudToolVersion.tryParse('0.10.2'), isNull);
      expect(EudToolVersion.tryParse('v0.10.2.5'), isNull);
      expect(EudToolVersion.tryParse('0.10.2.65536'), isNull);
      expect(() => EudToolVersion.parse('invalid'), throwsFormatException);
    });
  });

  group('EudToolInspectionResult', () {
    test('enforces ready and failure diagnostic invariants', () {
      final info = EudToolInfo(
        pathSource: EudToolPathSource.userSettings,
        installationPath: r'C:\euddraft',
        executablePath: r'C:\euddraft\euddraft.exe',
        versionFilePath: r'C:\euddraft\VERSION',
        version: EudToolVersion.parse('0.10.2.5'),
        companionPaths: const [r'C:\euddraft\libepScriptLib.dll'],
      );
      const error = EditorDiagnostic(
        code: 'TEST_ERROR',
        message: 'error',
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.compile,
      );

      expect(EudToolInspectionResult.ready(readyTool: info).isReady, isTrue);
      expect(
        () => EudToolInspectionResult.ready(
          readyTool: info,
          diagnostics: const [error],
        ),
        throwsArgumentError,
      );
      expect(
        () => EudToolInspectionResult.failure(
          diagnostics: const [
            EditorDiagnostic(
              code: 'TEST_WARNING',
              message: 'warning',
              severity: DiagnosticSeverity.warning,
              stage: DiagnosticStage.compile,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
