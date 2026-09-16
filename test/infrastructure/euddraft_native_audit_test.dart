import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_tool_manifest.dart';

void main() {
  const evidence = 'docs/research/euddraft-0.10.2.5';
  final shell = Platform.environment['POWERSHELL_TEST_EXECUTABLE'] ?? 'pwsh';
  final script = File('tool/audit_euddraft_native_versions.ps1').absolute.path;
  final zip = Platform.environment['EUDDRAFT_AUDIT_ZIP'];

  test(
    'native evidence covers every binary and preserves unknown versions',
    () {
      final manifest = EudToolManifest.decode(
        File('$evidence/manifest.json').readAsStringSync(),
      );
      final report =
          jsonDecode(File('$evidence/native-versions.json').readAsStringSync())
              as Map<String, dynamic>;
      final binaries = report['binaries'] as List;
      final expectedPaths = manifest.files.keys.where(
        (path) => RegExp(r'\.(exe|dll|pyd)$').hasMatch(path),
      );
      expect(binaries.map((b) => b['path']), unorderedEquals(expectedPaths));
      expect(report['artifactSha256'], manifest.artifactSha256);
      expect(report['executableRun'], false);
      expect(report['provenanceVerified'], false);
      for (final binary in binaries) {
        final file = manifest.files[binary['path']]!;
        expect(binary['size'], file.size);
        expect(binary['sha256'], file.sha256);
        if (binary['versionResource'] == false) {
          expect(binary['fileVersion'], isNull);
          expect(binary['productVersion'], isNull);
        }
      }
      expect(
        binaries.where((b) => b['versionResource'] == false),
        hasLength(5),
      );
      expect(
        binaries.singleWhere(
          (b) => b['path'] == 'python313.dll',
        )['fileVersion'],
        '3.13.5150.1013',
      );
    },
  );

  test(
    'native audit rejects wrong archive and preserves existing output',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'eud-native-negative-',
      );
      try {
        final source = File('${temporary.path}/wrong.zip');
        await source.writeAsBytes([0, 1]);
        final output = File('${temporary.path}/report.json');
        Future<ProcessResult> run() => Process.run(shell, [
          '-NoProfile',
          '-File',
          script,
          '-ZipPath',
          source.path,
          '-OutputPath',
          output.path,
        ]);
        final rejected = await run();
        expect(rejected.exitCode, isNot(0));
        expect(
          '${rejected.stdout}${rejected.stderr}',
          contains('Archive SHA-256 differs'),
        );
        expect(output.existsSync(), false);
        await output.writeAsString('preserve');
        final existing = await run();
        expect(existing.exitCode, isNot(0));
        expect(
          '${existing.stdout}${existing.stderr}',
          contains('Choose a new output file'),
        );
        expect(await output.readAsString(), 'preserve');
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'native resource audit reproduces pinned evidence and cleans temporary files',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'eud-native-pinned-',
      );
      try {
        final scratch = await Directory('${temporary.path}/scratch').create();
        final output = File('${temporary.path}/report.json');
        final result = await Process.run(
          shell,
          [
            '-NoProfile',
            '-File',
            script,
            '-ZipPath',
            zip!,
            '-OutputPath',
            output.path,
          ],
          environment: {'TEMP': scratch.path, 'TMP': scratch.path},
        );
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          jsonDecode(await output.readAsString()),
          jsonDecode(File('$evidence/native-versions.json').readAsStringSync()),
        );
        expect(await scratch.list().toList(), isEmpty);
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows || zip == null
        ? 'Set EUDDRAFT_AUDIT_ZIP to the pinned official ZIP.'
        : false,
  );
}
