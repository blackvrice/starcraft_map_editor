import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';

void main() {
  group('EudBuildConfiguration', () {
    test('stores an immutable SCR euddraft project configuration', () {
      final environment = {'BUILD_MODE': 'debug'};
      final compilerOptions = {'optimize': 'true'};
      final configuration = EudBuildConfiguration(
        baseMapPath: r'C:\Project\base\Map.scx',
        sourceRootPath: r'C:\Project\src\',
        entrySourcePath: r'c:/Project/src/main.EPS',
        outputMapPath: r'C:\Project\build\Map-eud.SCX',
        compilerPathOverride: r'C:\Tools\euddraft',
        compilerOptions: compilerOptions,
        environmentOverrides: environment,
      );
      environment['BUILD_MODE'] = 'changed';
      compilerOptions['optimize'] = 'false';

      expect(configuration.baseMapPath, r'C:\Project\base\Map.scx');
      expect(configuration.sourceRootPath, r'C:\Project\src\');
      expect(configuration.entrySourcePath, r'c:/Project/src/main.EPS');
      expect(configuration.outputMapPath, r'C:\Project\build\Map-eud.SCX');
      expect(configuration.compilerPathOverride, r'C:\Tools\euddraft');
      expect(
        configuration.compilerProfile,
        EudCompilerProfile.starcraftRemastered,
      );
      expect(configuration.compilerProfile.id, 'scr-euddraft');
      expect(configuration.compilerProfile.game, 'StarCraft: Remastered');
      expect(configuration.compilerProfile.language, 'epScript');
      expect(configuration.compilerOptions, {'optimize': 'true'});
      expect(configuration.environmentOverrides, {'BUILD_MODE': 'debug'});
      expect(
        () => configuration.compilerOptions['other'] = 'value',
        throwsUnsupportedError,
      );
      expect(
        () => configuration.environmentOverrides['OTHER'] = 'value',
        throwsUnsupportedError,
      );
    });

    test('accepts drive roots and UNC project paths', () {
      final driveRoot = EudBuildConfiguration(
        baseMapPath: r'C:\base.scx',
        sourceRootPath: r'C:\',
        entrySourcePath: r'C:\main.eps',
        outputMapPath: r'D:\build\output.scx',
      );
      final unc = EudBuildConfiguration(
        baseMapPath: r'\\server\share\Project\base\Map.scx',
        sourceRootPath: r'\\server\share\Project\src',
        entrySourcePath: r'\\SERVER\SHARE\project\src\main.eps',
        outputMapPath: r'\\server\share\Project\build\Map-eud.scx',
        compilerPathOverride: r'\\server\share\Tools\euddraft',
      );

      expect(driveRoot.entrySourcePath, r'C:\main.eps');
      expect(unc.compilerPathOverride, r'\\server\share\Tools\euddraft');
    });

    test('requires absolute Windows paths for every configured location', () {
      EudBuildConfiguration create({
        String baseMapPath = r'C:\Project\base\Map.scx',
        String sourceRootPath = r'C:\Project\src',
        String entrySourcePath = r'C:\Project\src\main.eps',
        String outputMapPath = r'C:\Project\build\Map-eud.scx',
        String? compilerPathOverride,
      }) {
        return EudBuildConfiguration(
          baseMapPath: baseMapPath,
          sourceRootPath: sourceRootPath,
          entrySourcePath: entrySourcePath,
          outputMapPath: outputMapPath,
          compilerPathOverride: compilerPathOverride,
        );
      }

      expect(() => create(baseMapPath: 'base/Map.scx'), throwsArgumentError);
      expect(() => create(sourceRootPath: 'src'), throwsArgumentError);
      expect(
        () => create(entrySourcePath: 'src/main.eps'),
        throwsArgumentError,
      );
      expect(
        () => create(outputMapPath: 'build/Map-eud.scx'),
        throwsArgumentError,
      );
      expect(
        () => create(compilerPathOverride: 'tools/euddraft'),
        throwsArgumentError,
      );
      expect(
        () => create(baseMapPath: r' C:\Project\base\Map.scx'),
        throwsArgumentError,
      );
      expect(
        () => create(outputMapPath: 'C:\\Project\\build\\Map-eud.scx '),
        throwsArgumentError,
      );
    });

    test('requires map, epScript, and EUD output extensions', () {
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.zip',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scm',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\main.py',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scm',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scm',
        ),
        throwsArgumentError,
      );
    });

    test('never allows the output to overwrite the base map', () {
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\Maps\Map.scx',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\main.eps',
          outputMapPath: r'c:/project/maps/MAP.SCX',
        ),
        throwsArgumentError,
      );
    });

    test('requires the entry source to stay inside the source root', () {
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\outside\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\CON',
          entrySourcePath: r'C:\Project\CON\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src-other\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
    });

    test('keeps generated output outside the source tree', () {
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\main.eps',
          outputMapPath: r'C:\Project\src\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
    });

    test('rejects ambiguous or unsafe Windows path segments', () {
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\..\outside\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\src.',
          entrySourcePath: r'C:\Project\src.\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\main.eps',
          outputMapPath: r'\\?\C:\Project\build\Map-eud.scx',
        ),
        throwsArgumentError,
      );
    });

    test('validates environment overrides at the project boundary', () {
      expect(
        () => EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
          environmentOverrides: const {'Path': 'first', 'PATH': 'second'},
        ),
        throwsArgumentError,
      );
    });

    test('validates compiler options before settings serialization', () {
      EudBuildConfiguration create(Map<String, String> compilerOptions) {
        return EudBuildConfiguration(
          baseMapPath: r'C:\Project\base\Map.scx',
          sourceRootPath: r'C:\Project\src',
          entrySourcePath: r'C:\Project\src\main.eps',
          outputMapPath: r'C:\Project\build\Map-eud.scx',
          compilerOptions: compilerOptions,
        );
      }

      expect(() => create(const {'': 'value'}), throwsArgumentError);
      expect(
        () => create(const {'invalid option': 'value'}),
        throwsArgumentError,
      );
      expect(
        () => create(const {'valid-option': 'line1\nline2'}),
        throwsArgumentError,
      );
    });

    test('creates tool inspection and compiler process requests', () {
      final configuration = EudBuildConfiguration(
        baseMapPath: r'C:\Project\base\Map.scx',
        sourceRootPath: r'C:\Project\src',
        entrySourcePath: r'C:\Project\src\main.eps',
        outputMapPath: r'C:\Project\build\Map-eud.scx',
        compilerPathOverride: r'C:\Project\tools\euddraft',
        environmentOverrides: const {'BUILD_MODE': 'release'},
      );
      final inspectionRequest = configuration.createToolInspectionRequest(
        userSettingsPath: r'C:\UserTools\euddraft',
        bundledPath: r'C:\App\euddraft',
      );
      final tool = _tool();
      final compilerRequest = configuration.createCompilerRequest(
        buildId: 'build-configuration',
        tool: tool,
        settingsFilePath: r'C:\Project\.build\request.eds',
        timeout: const Duration(minutes: 2),
      );

      expect(
        inspectionRequest.selectedCandidate?.path,
        r'C:\Project\tools\euddraft',
      );
      expect(
        inspectionRequest.selectedCandidate?.source,
        EudToolPathSource.projectProfile,
      );
      expect(compilerRequest.buildId, 'build-configuration');
      expect(compilerRequest.tool, same(tool));
      expect(
        compilerRequest.settingsFilePath,
        r'C:\Project\.build\request.eds',
      );
      expect(compilerRequest.timeout, const Duration(minutes: 2));
      expect(compilerRequest.environmentOverrides, {'BUILD_MODE': 'release'});
    });
  });
}

EudToolInfo _tool() {
  return EudToolInfo(
    pathSource: EudToolPathSource.projectProfile,
    installationPath: r'C:\Project\tools\euddraft',
    executablePath: r'C:\Project\tools\euddraft\euddraft.exe',
    versionFilePath: r'C:\Project\tools\euddraft\VERSION',
    version: EudToolVersion.parse('0.10.2.5'),
    companionPaths: const [r'C:\Project\tools\euddraft\python3.dll'],
  );
}
