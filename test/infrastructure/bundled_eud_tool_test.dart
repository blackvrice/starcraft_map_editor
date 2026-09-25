import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/domain/eud/eud_tool_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/bundled_eud_tool.dart';

void main() {
  test('compiled trust inventory matches reviewed packaging inventory', () {
    final expected = EudToolManifest.decode(
      File('tool/eud_bundle/manifest.json').readAsStringSync(),
    );
    expect(BundledEudTool.manifest.encode(), expected.encode());
    expect(expected.files.containsKey('BUNDLE-NOTICE.txt'), isTrue);
    expect(expected.files.length, 86);
  });

  test('bundle path is relative to the executable, including spaces', () {
    final executable = File('build/app folder/editor.exe').absolute;
    final expected = Directory(
      '${executable.parent.path}/tools/euddraft/0.10.2.5-editor.1',
    );
    expect(
      Directory(BundledEudTool.pathForExecutable(executable.path)).uri,
      expected.absolute.uri,
    );
  });

  final archive = Platform.environment['EUDDRAFT_AUDIT_ZIP'];
  test(
    'packaging is reproducible and rejects altered or extra files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'managed-eud-package-',
      );
      addTearDown(() => root.delete(recursive: true));
      final output = Directory('${root.path}/package');
      Future<ProcessResult> pack(String zip, String path) =>
          Process.run('pwsh', [
            '-NoProfile',
            '-File',
            'tool/prepare_eud_bundle.ps1',
            '-ArchivePath',
            zip,
            '-OutputDirectory',
            path,
          ]);
      final wrong = File('${root.path}/wrong.zip')..writeAsStringSync('wrong');
      final rejected = await pack(wrong.path, output.path);
      expect(rejected.exitCode, isNot(0));
      expect(output.existsSync(), isFalse);
      final result = await pack(archive!, output.path);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final inspector = BundledEudTool.inspector();
      final request = EudToolInspectionRequest(bundledPath: output.path);
      expect((await inspector.inspect(request)).isReady, isTrue);
      expect((await pack(archive, output.path)).exitCode, 0);
      final notice = File('${output.path}/BUNDLE-NOTICE.txt');
      final original = await notice.readAsBytes();
      final changed = [...original]..[0] ^= 1;
      await notice.writeAsBytes(changed);
      expect((await pack(archive, output.path)).exitCode, isNot(0));
      expect((await inspector.inspect(request)).isReady, isFalse);
      await notice.writeAsBytes(original);
      await File('${output.path}/unexpected.txt').writeAsString('extra');
      expect((await pack(archive, output.path)).exitCode, isNot(0));
      expect((await inspector.inspect(request)).isReady, isFalse);
    },
    skip: !Platform.isWindows || archive == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
