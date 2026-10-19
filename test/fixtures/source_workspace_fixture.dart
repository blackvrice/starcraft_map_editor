import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:starcraft_map_editor/application/ports/source_workspace_gateway.dart';

final class MemorySourceWorkspace implements SourceWorkspaceGateway {
  final text = <String, String>{
    'main.eps': 'import util;\nfunction onPluginStart() {}',
    'util.eps': 'function Work() {}',
    'pkg/main.py': 'from .util import Work',
    'pkg/util.py': 'def Work():\n    pass',
    'data.lua': 'function Work()\nend',
  };
  int scans = 0, reads = 0, saves = 0;
  Completer<void>? pending;
  String chosen = r'C:\Project\src';
  SourceWorkspaceFile file(String relative) => SourceWorkspaceFile(
    relativePath: relative,
    path: '$chosen\\${relative.replaceAll('/', '\\')}',
    text: text[relative]!,
    revision: sha256.convert(utf8.encode(text[relative]!)).toString(),
  );
  @override
  Future<String?> chooseRoot() async => chosen;
  @override
  Future<SourceWorkspaceScan> scan(String root) async {
    scans++;
    await pending?.future;
    return SourceWorkspaceScan(root, text.keys.map(file));
  }

  @override
  Future<SourceWorkspaceFile> read(String root, String relativePath) async {
    reads++;
    return file(relativePath);
  }

  @override
  Future<SourceWorkspaceFile> save(
    String root,
    String relativePath,
    String value,
    String expectedRevision,
  ) async {
    saves++;
    await pending?.future;
    if (file(relativePath).revision != expectedRevision) {
      throw StateError('SOURCE_EXTERNAL_CHANGE');
    }
    text[relativePath] = value;
    return file(relativePath);
  }
}
