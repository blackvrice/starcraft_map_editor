import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_tool_manifest.dart';

void main() {
  final script = File('tool/audit_euddraft_package.ps1').absolute.path;
  final zip = Platform.environment['EUDDRAFT_AUDIT_ZIP'];
  final shell = Platform.environment['POWERSHELL_TEST_EXECUTABLE'] ?? 'pwsh';
  const evidence = 'docs/research/euddraft-0.10.2.5';
  test(
    'review inventory satisfies app manifest contract and component evidence',
    () {
      final manifest = EudToolManifest.decode(
        File('$evidence/manifest.json').readAsStringSync(),
      );
      final audit =
          jsonDecode(File('$evidence/audit.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(manifest.files, hasLength(77));
      expect(
        manifest.files.values.fold<int>(0, (sum, file) => sum + file.size),
        audit['unpackedBytes'],
      );
      expect(audit['artifactSha256'], manifest.artifactSha256);
      expect(audit['redistributionReview'], 'pending');
      expect(audit['executableRun'], false);
      final components = audit['components'] as List;
      expect(
        components.singleWhere((c) => c['Name'] == 'eudplib')['Version'],
        '0.80.6',
      );
      expect(manifest.files['lib/scbank_core.py']!.size, 0);
    },
  );

  test('audit rejects untrusted bytes without creating outputs', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'eud-audit-negative-',
    );
    try {
      final source = File('${temporary.path}/wrong.zip');
      await source.writeAsBytes([80, 75, 0, 1]);
      final output = '${temporary.path}/report';
      final result = await Process.run(shell, [
        '-NoProfile',
        '-File',
        script,
        '-ZipPath',
        source.path,
        '-OutputDirectory',
        output,
      ]);
      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}${result.stderr}',
        contains('Archive SHA-256 differs'),
      );
      expect(Directory(output).existsSync(), isFalse);
    } finally {
      await temporary.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);

  test(
    'pinned ZIP reproduces review files and refuses output overwrite without executing code',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'eud-audit-pinned-',
      );
      try {
        final output = '${temporary.path}/report';
        final arguments = [
          '-NoProfile',
          '-File',
          script,
          '-ZipPath',
          zip!,
          '-OutputDirectory',
          output,
        ];
        final result = await Process.run(shell, arguments);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        for (final name in ['manifest', 'audit']) {
          final generated = jsonDecode(
            await File('$output/euddraft-0.10.2.5.$name.json').readAsString(),
          );
          final committed = jsonDecode(
            await File('$evidence/$name.json').readAsString(),
          );
          expect(generated, committed);
        }
        final before = await File(
          '$output/euddraft-0.10.2.5.manifest.json',
        ).readAsBytes();
        final again = await Process.run(shell, arguments);
        expect(again.exitCode, isNot(0));
        expect(
          '${again.stdout}${again.stderr}',
          contains('Choose a new output directory'),
        );
        expect(
          await File('$output/euddraft-0.10.2.5.manifest.json').readAsBytes(),
          before,
        );
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows || zip == null
        ? 'Set EUDDRAFT_AUDIT_ZIP to the pinned official ZIP.'
        : false,
  );
}
