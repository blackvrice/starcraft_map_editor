import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/local_eud_tool_inspector.dart';

void main() {
  final externalInstallationPath =
      Platform.environment['EUDDRAFT_TEST_INSTALLATION'];

  group('LocalEudToolInspector', () {
    late Directory temporaryRoot;
    late LocalEudToolInspector inspector;

    setUp(() async {
      temporaryRoot = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_euddraft_inspection_',
      );
      inspector = LocalEudToolInspector(isWindows: () => true);
    });

    tearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });

    test(
      'accepts the official release layout without executing the tool',
      () async {
        final installation = await _createInstallation(temporaryRoot);

        final result = await inspector.inspect(
          EudToolInspectionRequest(userSettingsPath: installation.path),
        );

        expect(result.isReady, isTrue);
        expect(result.diagnostics, isEmpty);
        expect(result.tool?.pathSource, EudToolPathSource.userSettings);
        expect(result.tool?.installationPath, installation.absolute.path);
        expect(
          result.tool?.executablePath,
          File(
            '${installation.path}${Platform.pathSeparator}euddraft.exe',
          ).absolute.path,
        );
        expect(result.tool?.version.toString(), '0.10.2.5');
        expect(result.tool?.companionPaths, hasLength(6));
      },
    );

    test(
      'inspects an externally supplied official installation',
      () async {
        final result = await inspector.inspect(
          EudToolInspectionRequest(userSettingsPath: externalInstallationPath),
        );

        expect(result.isReady, isTrue, reason: '${result.diagnostics}');
        expect(result.tool?.version.toString(), '0.10.2.5');
      },
      skip: externalInstallationPath == null || externalInstallationPath.isEmpty
          ? 'Set EUDDRAFT_TEST_INSTALLATION to an extracted official release.'
          : false,
    );

    test('accepts a direct executable path', () async {
      final installation = await _createInstallation(temporaryRoot);
      final executablePath =
          '${installation.path}${Platform.pathSeparator}euddraft.exe';

      final result = await inspector.inspect(
        EudToolInspectionRequest(projectProfilePath: executablePath),
      );

      expect(result.isReady, isTrue);
      expect(result.tool?.pathSource, EudToolPathSource.projectProfile);
      expect(result.tool?.executablePath, File(executablePath).absolute.path);
    });

    test('does not fall back past a configured higher-priority path', () async {
      final installation = await _createInstallation(temporaryRoot);

      final result = await inspector.inspect(
        EudToolInspectionRequest(
          projectProfilePath:
              '${temporaryRoot.path}${Platform.pathSeparator}missing',
          userSettingsPath: installation.path,
        ),
      );

      expect(result.isReady, isFalse);
      expect(
        result.diagnostics.single.code,
        EudToolDiagnosticCodes.executableMissing,
      );
    });

    test('reports a missing configured path', () async {
      final result = await inspector.inspect(const EudToolInspectionRequest());

      expect(result.isReady, isFalse);
      expect(
        result.diagnostics.single.code,
        EudToolDiagnosticCodes.pathNotConfigured,
      );
    });

    test('rejects a relative path before filesystem inspection', () async {
      final result = await inspector.inspect(
        const EudToolInspectionRequest(userSettingsPath: 'tools/euddraft'),
      );

      expect(result.isReady, isFalse);
      expect(
        result.diagnostics.single.code,
        EudToolDiagnosticCodes.pathInvalid,
      );
    });

    test('reports a missing executable in an installation folder', () async {
      final installation = Directory(
        '${temporaryRoot.path}${Platform.pathSeparator}empty',
      );
      await installation.create();

      final result = await inspector.inspect(
        EudToolInspectionRequest(userSettingsPath: installation.path),
      );

      expect(result.isReady, isFalse);
      expect(
        result.diagnostics.single.code,
        EudToolDiagnosticCodes.executableMissing,
      );
    });

    test('rejects a different executable and an empty euddraft.exe', () async {
      final installation = await _createInstallation(
        temporaryRoot,
        name: 'invalid-executables',
      );
      final otherExecutable = File(
        '${installation.path}${Platform.pathSeparator}other.exe',
      );
      await otherExecutable.writeAsBytes([1], flush: true);

      final wrongNameResult = await inspector.inspect(
        EudToolInspectionRequest(userSettingsPath: otherExecutable.path),
      );
      await File(
        '${installation.path}${Platform.pathSeparator}euddraft.exe',
      ).writeAsBytes(const [], flush: true);
      final emptyResult = await inspector.inspect(
        EudToolInspectionRequest(userSettingsPath: installation.path),
      );

      expect(
        wrongNameResult.diagnostics.single.code,
        EudToolDiagnosticCodes.pathInvalid,
      );
      expect(
        emptyResult.diagnostics.single.code,
        EudToolDiagnosticCodes.executableMissing,
      );
    });

    test('reports missing and malformed version files', () async {
      final missingVersion = await _createInstallation(
        temporaryRoot,
        includeVersion: false,
        name: 'missing-version',
      );
      final malformedVersion = await _createInstallation(
        temporaryRoot,
        version: 'release-latest',
        name: 'malformed-version',
      );

      final missingResult = await inspector.inspect(
        EudToolInspectionRequest(userSettingsPath: missingVersion.path),
      );
      final malformedResult = await inspector.inspect(
        EudToolInspectionRequest(userSettingsPath: malformedVersion.path),
      );

      expect(
        missingResult.diagnostics.single.code,
        EudToolDiagnosticCodes.versionMissing,
      );
      expect(
        malformedResult.diagnostics.single.code,
        EudToolDiagnosticCodes.versionInvalid,
      );
    });

    test('rejects a VERSION file above the read limit', () async {
      final installation = await _createInstallation(
        temporaryRoot,
        version: '0.10.2.5${List.filled(64, ' ').join()}',
      );

      final result = await inspector.inspect(
        EudToolInspectionRequest(userSettingsPath: installation.path),
      );

      expect(
        result.diagnostics.single.code,
        EudToolDiagnosticCodes.versionInvalid,
      );
      expect(result.diagnostics.single.rawDetails, contains('maximumBytes=64'));
    });

    test(
      'blocks versions outside the explicit compatibility allowlist',
      () async {
        final installation = await _createInstallation(
          temporaryRoot,
          version: '0.10.2.4',
        );

        final result = await inspector.inspect(
          EudToolInspectionRequest(userSettingsPath: installation.path),
        );

        expect(result.isReady, isFalse);
        expect(
          result.diagnostics.single.code,
          EudToolDiagnosticCodes.versionUnsupported,
        );
        expect(result.diagnostics.single.remediation, contains('0.10.2.5'));
      },
    );

    test('reports every missing required companion', () async {
      final installation = await _createInstallation(
        temporaryRoot,
        omittedCompanions: {'libepScriptLib.dll', 'lib/library.zip'},
      );

      final result = await inspector.inspect(
        EudToolInspectionRequest(userSettingsPath: installation.path),
      );

      expect(result.isReady, isFalse);
      expect(
        result.diagnostics.single.code,
        EudToolDiagnosticCodes.companionMissing,
      );
      expect(
        result.diagnostics.single.rawDetails,
        contains('libepScriptLib.dll'),
      );
      expect(result.diagnostics.single.rawDetails, contains('lib/library.zip'));
    });

    test('requires a versioned Python runtime DLL', () async {
      final installation = await _createInstallation(
        temporaryRoot,
        includeRuntimeDll: false,
      );

      final result = await inspector.inspect(
        EudToolInspectionRequest(userSettingsPath: installation.path),
      );

      expect(result.isReady, isFalse);
      expect(
        result.diagnostics.single.code,
        EudToolDiagnosticCodes.companionMissing,
      );
      expect(
        result.diagnostics.single.rawDetails,
        contains('python3<runtime>.dll'),
      );
    });

    test('reports unsupported platforms without touching the path', () async {
      inspector = LocalEudToolInspector(isWindows: () => false);

      final result = await inspector.inspect(
        const EudToolInspectionRequest(
          userSettingsPath: r'C:\euddraft\euddraft.exe',
        ),
      );

      expect(result.isReady, isFalse);
      expect(
        result.diagnostics.single.code,
        EudToolDiagnosticCodes.platformUnsupported,
      );
    });
  });
}

Future<Directory> _createInstallation(
  Directory root, {
  String name = 'euddraft',
  String version = '0.10.2.5',
  bool includeVersion = true,
  bool includeRuntimeDll = true,
  Set<String> omittedCompanions = const {},
}) async {
  final installation = Directory('${root.path}${Platform.pathSeparator}$name');
  await installation.create(recursive: true);
  await _writeBytes(installation, 'euddraft.exe', [0x4d, 0x5a]);
  if (includeVersion) {
    await File(
      '${installation.path}${Platform.pathSeparator}VERSION',
    ).writeAsString(version, flush: true);
  }

  final companionBytes = {
    'libepScriptLib.dll': [1],
    'python3.dll': [2],
    'license.txt': [3],
    'lib/library.zip': [4],
    'lib/eudplib.bindings._rust.pyd': [5],
  };
  for (final entry in companionBytes.entries) {
    if (!omittedCompanions.contains(entry.key)) {
      await _writeBytes(installation, entry.key, entry.value);
    }
  }
  if (includeRuntimeDll) {
    await _writeBytes(installation, 'python313.dll', [6]);
  }
  return installation;
}

Future<void> _writeBytes(
  Directory installation,
  String relativePath,
  List<int> bytes,
) async {
  final file = File(
    relativePath
        .split('/')
        .fold(
          installation.path,
          (current, part) => '$current${Platform.pathSeparator}$part',
        ),
  );
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}
