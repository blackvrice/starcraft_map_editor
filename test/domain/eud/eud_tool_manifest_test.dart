import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_tool_manifest.dart';

EudToolManifest manifest(Map<String, EudToolFile> extra) => EudToolManifest(
  version: '0.10.2.5',
  artifactSha256: 'a' * 64,
  sourceUrl: 'https://example.test/tool.zip',
  files: {
    for (final name in ['euddraft.exe', 'VERSION', 'license.txt'])
      name: EudToolFile(size: 1, sha256: 'b' * 64),
    ...extra,
  },
);

void main() {
  test('roundtrip is deterministic and inventory is immutable', () {
    final file = EudToolFile(size: 10, sha256: 'c' * 64);
    final a = manifest({'z.dll': file, 'a.dll': file});
    final b = manifest({'a.dll': file, 'z.dll': file});
    expect(a.encode(), b.encode());
    expect(EudToolManifest.decode(a.encode()).encode(), a.encode());
    expect(() => a.files.clear(), throwsUnsupportedError);
  });
  test(
    'rejects traversal, alternate streams, Windows aliases and collisions',
    () {
      for (final path in [
        '../x',
        '/x',
        'C:/x',
        'lib\\x',
        'lib//x',
        'lib/./x',
        'a:stream',
        'CON.txt',
        'lib/nul',
        'a.',
        'a ',
      ]) {
        expect(
          () => manifest({path: EudToolFile(size: 1, sha256: 'a' * 64)}),
          throwsFormatException,
          reason: path,
        );
      }
      final file = EudToolFile(size: 1, sha256: 'a' * 64);
      expect(
        () => manifest({'VERSION': file, 'version': file}),
        throwsFormatException,
      );
      expect(
        () => manifest({'lib': file, 'lib/a': file}),
        throwsFormatException,
      );
    },
  );
  test(
    'rejects malformed/future schema, invalid hashes and required file omissions',
    () {
      final json = jsonDecode(manifest({}).encode()) as Map<String, dynamic>;
      for (final patch in [
        {'schemaVersion': 2},
        {'schemaVersion': 1.0},
        {'extra': true},
        {'artifactSha256': 'invalid'},
        {'sourceUrl': 'file:///tool'},
        {'files': <String, dynamic>{}},
      ]) {
        expect(
          () => EudToolManifest.decode(jsonEncode({...json, ...patch})),
          throwsFormatException,
        );
      }
      expect(
        () => EudToolFile(size: -1, sha256: 'a' * 64),
        throwsFormatException,
      );
    },
  );
}
