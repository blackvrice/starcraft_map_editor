import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_tool_manifest.dart';

void main() {
  const evidence = 'docs/research/euddraft-0.10.2.5';
  final script = File('tool/compare_euddraft_upstream.ps1').absolute.path;
  final shell = Platform.environment['POWERSHELL_TEST_EXECUTABLE'] ?? 'pwsh';
  final directory = Platform.environment['EUDDRAFT_UPSTREAM_AUDIT_DIRECTORY'];
  final expected =
      jsonDecode(File('$evidence/upstream-comparison.json').readAsStringSync())
          as Map<String, dynamic>;

  test('upstream evidence accounts for identical and different binaries', () {
    final manifest = EudToolManifest.decode(
      File('$evidence/manifest.json').readAsStringSync(),
    );
    expect(expected['executableRun'], false);
    expect(expected['redistributionReview'], 'pending');
    final comparisons = expected['comparisons'] as List;
    final matches = <String>{};
    for (final comparison in comparisons) {
      for (final path in comparison['identicalBundlePaths'] as List) {
        expect(manifest.files[path]!.sha256, comparison['sha256']);
        expect(manifest.files[path]!.size, comparison['size']);
        matches.add(path as String);
      }
    }
    expect(matches, hasLength(23));
    expect(
      matches,
      containsAll(['lib/eudplib.bindings._rust.pyd', 'lib/libffi-8.dll']),
    );
    for (final path in [
      'vcruntime140.dll',
      'vcruntime140_1.dll',
      'eudplib/epscript/libepScriptLib.dll',
    ]) {
      expect(
        comparisons.singleWhere(
          (c) => c['path'] == path,
        )['identicalBundlePaths'],
        isEmpty,
      );
    }
  });

  test(
    'upstream comparison rejects untrusted first input without output',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'eud-upstream-negative-',
      );
      try {
        final wrong = File('${temporary.path}/wrong.zip');
        await wrong.writeAsBytes([0]);
        final output = File('${temporary.path}/report.json');
        final result = await Process.run(shell, [
          '-NoProfile',
          '-File',
          script,
          '-EuddraftZip',
          wrong.path,
          '-PythonZip',
          wrong.path,
          '-EudplibWheel',
          wrong.path,
          '-OutputPath',
          output.path,
        ]);
        expect(result.exitCode, isNot(0));
        expect(
          '${result.stdout}${result.stderr}',
          contains('Archive SHA-256 differs: euddraft'),
        );
        expect(output.existsSync(), false);
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'official archives reproduce evidence and every input is pinned',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'eud-upstream-pinned-',
      );
      try {
        final inputs = [
          '$directory/euddraft0.10.2.5.zip',
          '$directory/python-3.13.5-embed-amd64.zip',
          '$directory/eudplib-0.80.6-cp310-abi3-win_amd64.whl',
        ];
        final output = File('${temporary.path}/report.json');
        Future<ProcessResult> run(List<String> sources) => Process.run(shell, [
          '-NoProfile',
          '-File',
          script,
          '-EuddraftZip',
          sources[0],
          '-PythonZip',
          sources[1],
          '-EudplibWheel',
          sources[2],
          '-OutputPath',
          output.path,
        ]);
        final wrong = File('${temporary.path}/wrong.zip');
        await wrong.writeAsBytes([0]);
        for (var i = 0; i < inputs.length; i++) {
          final sources = [...inputs]..[i] = wrong.path;
          final rejected = await run(sources);
          expect(rejected.exitCode, isNot(0));
          expect(
            '${rejected.stdout}${rejected.stderr}',
            contains('Archive SHA-256 differs'),
          );
          expect(output.existsSync(), false);
        }
        final result = await run(inputs);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(jsonDecode(await output.readAsString()), expected);
        final bytes = await output.readAsBytes();
        final again = await run(inputs);
        expect(again.exitCode, isNot(0));
        expect(
          '${again.stdout}${again.stderr}',
          contains('Choose a new output file'),
        );
        expect(await output.readAsBytes(), bytes);
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows || directory == null
        ? 'Set EUDDRAFT_UPSTREAM_AUDIT_DIRECTORY to the three official archives.'
        : false,
  );
}
