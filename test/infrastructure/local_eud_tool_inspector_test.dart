import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:starcraft_map_editor/domain/eud/eud_tool_manifest.dart';

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

    Future<EudToolManifest> inventory(Directory root) async {
      final files = <String, EudToolFile>{};
      await for (final entry in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is File) {
          final bytes = await entry.readAsBytes();
          files[entry.path
              .substring(root.path.length + 1)
              .replaceAll('\\', '/')] = EudToolFile(
            size: bytes.length,
            sha256: sha256.convert(bytes).toString(),
          );
        }
      }
      return EudToolManifest(
        version: '0.10.2.5',
        artifactSha256: 'a' * 64,
        sourceUrl: 'https://example.test/fixture.zip',
        files: files,
      );
    }

    test(
      'records immutable core hashes and detects same-size replacement',
      () async {
        final root = await _createInstallation(temporaryRoot);
        final request = EudToolInspectionRequest(userSettingsPath: root.path);
        final before = (await inspector.inspect(request)).tool!;
        expect(before.contentHashes.length, 9);
        expect(
          before.contentHashes['euddraft.exe'],
          sha256.convert([0x4d, 0x5a]).toString(),
        );
        expect(() => before.contentHashes.clear(), throwsUnsupportedError);
        expect(
          (await inspector.inspect(request)).tool!.contentHashes,
          before.contentHashes,
        );

        for (final name in [
          'euddraft.exe',
          'lib/library.zip',
          'lib/freezeMpq.pyd',
          'python313.dll',
        ]) {
          final file = File('${root.path}/$name');
          final bytes = await file.readAsBytes();
          await file.writeAsBytes(List.filled(bytes.length, 99));
          final changed = (await inspector.inspect(request)).tool!;
          expect(changed.version, before.version);
          expect(
            changed.contentHashes[name.toLowerCase()],
            isNot(before.contentHashes[name.toLowerCase()]),
          );
          await file.writeAsBytes(bytes);
        }
        await _writeBytes(root, 'python314.dll', [8]);
        final added = (await inspector.inspect(request)).tool!;
        expect(added.contentHashes.length, before.contentHashes.length + 1);
        expect(added.contentHashes, contains('python314.dll'));
      },
    );

    test(
      'bundled candidate requires app inventory while explicit external remains available',
      () async {
        final root = await _createInstallation(temporaryRoot);
        final blocked = await inspector.inspect(
          EudToolInspectionRequest(bundledPath: root.path),
        );
        expect(
          blocked.diagnostics.single.code,
          EudToolDiagnosticCodes.bundleManifestMissing,
        );
        final external = await inspector.inspect(
          EudToolInspectionRequest(
            userSettingsPath: root.path,
            bundledPath: 'missing',
          ),
        );
        expect(external.isReady, isTrue);
        expect(external.tool!.pathSource, EudToolPathSource.userSettings);
      },
    );
    test(
      'checks full bundle hashes and rejects extra or missing inventory files',
      () async {
        final root = await _createInstallation(temporaryRoot);
        final extra = File('${root.path}/optional.dat');
        await extra.writeAsString('abc');
        inspector = LocalEudToolInspector(
          isWindows: () => true,
          bundledManifest: await inventory(root),
        );
        final request = EudToolInspectionRequest(bundledPath: root.path);
        expect((await inspector.inspect(request)).isReady, isTrue);
        await extra.writeAsString('xyz');
        expect(
          (await inspector.inspect(request)).diagnostics.single.code,
          EudToolDiagnosticCodes.bundleIntegrityFailed,
        );
        await extra.writeAsString('abc');
        final injected = File('${root.path}/injected.py');
        await injected.writeAsString('not executed');
        expect(
          (await inspector.inspect(request)).diagnostics.single.code,
          EudToolDiagnosticCodes.bundleIntegrityFailed,
        );
        await injected.delete();
        await extra.delete();
        expect(
          (await inspector.inspect(request)).diagnostics.single.code,
          EudToolDiagnosticCodes.bundleIntegrityFailed,
        );
      },
    );
    test(
      'bundle version mismatch is rejected without changing allowlist',
      () async {
        final root = await _createInstallation(temporaryRoot);
        final valid = await inventory(root);
        inspector = LocalEudToolInspector(
          isWindows: () => true,
          bundledManifest: EudToolManifest(
            version: '0.10.2.4',
            artifactSha256: valid.artifactSha256,
            sourceUrl: valid.sourceUrl,
            files: valid.files,
          ),
        );
        expect(
          (await inspector.inspect(
            EudToolInspectionRequest(bundledPath: root.path),
          )).diagnostics.single.code,
          EudToolDiagnosticCodes.bundleIntegrityFailed,
        );
      },
    );

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
        expect(result.tool?.companionPaths, hasLength(7));
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

    test(
      'verifies official installation against the audited bundle manifest',
      () async {
        final manifest = EudToolManifest.decode(
          await File(
            'docs/research/euddraft-0.10.2.5/manifest.json',
          ).readAsString(),
        );
        final result =
            await LocalEudToolInspector(
              isWindows: () => true,
              bundledManifest: manifest,
            ).inspect(
              EudToolInspectionRequest(bundledPath: externalInstallationPath),
            );
        expect(result.isReady, true, reason: '${result.diagnostics}');
        expect(result.tool!.pathSource, EudToolPathSource.bundled);
        expect(
          result.tool!.companionPaths,
          contains(endsWith('freezeMpq.pyd')),
        );
      },
      skip: externalInstallationPath == null || externalInstallationPath.isEmpty
          ? 'Set EUDDRAFT_TEST_INSTALLATION to the unmodified audited release.'
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

    for (final source in EudToolPathSource.values) {
      for (final state in ['missing', 'empty', 'directory']) {
        test(
          'rejects $state freezeMpq for ${source.name} before building',
          () async {
            final installation = await _createInstallation(
              temporaryRoot,
              omittedCompanions: {'lib/freezeMpq.pyd'},
            );
            final module = File('${installation.path}/lib/freezeMpq.pyd');
            if (state == 'empty') {
              await module.writeAsBytes([]);
            } else if (state == 'directory') {
              await Directory(module.path).create();
            }
            // Even a bundle inventory matching the incomplete installation must
            // not replace the runtime's required companion checks.
            inspector = LocalEudToolInspector(
              isWindows: () => true,
              bundledManifest: await inventory(installation),
            );
            final result = await inspector.inspect(
              EudToolInspectionRequest(
                projectProfilePath: source == EudToolPathSource.projectProfile
                    ? installation.path
                    : null,
                userSettingsPath: source == EudToolPathSource.userSettings
                    ? installation.path
                    : null,
                bundledPath: installation.path,
              ),
            );
            expect(result.isReady, false);
            expect(result.tool, isNull);
            expect(
              result.diagnostics.single.code,
              EudToolDiagnosticCodes.companionMissing,
            );
            expect(
              result.diagnostics.single.rawDetails,
              contains('lib/freezeMpq.pyd'),
            );
            if (state != 'missing') {
              expect(
                await FileSystemEntity.type(module.path),
                state == 'empty'
                    ? FileSystemEntityType.file
                    : FileSystemEntityType.directory,
              );
            }
          },
        );
      }
    }

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
    'lib/freezeMpq.pyd': [7],
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
