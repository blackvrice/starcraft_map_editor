import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/source_workspace_index.dart';

void main() {
  test('indexes declarations/import aliases without executing source', () {
    final index = SourceWorkspaceIndex({
      'main.eps':
          'import util as u;\nfunction onPluginStart() {\n const local = 1;\n}\n// import fake;\nconst label="import fake;";',
      'util.eps': 'function Work() {}\nconst Count=1;',
      'main.py':
          'import pkg.util as helper\nfrom pkg.util import Work as run\nvalue=1\n"""\nimport fake\n"""',
      'pkg/util.py': 'def Work():\n    pass\nCount=1',
    });
    expect(
      index.completions('main.eps'),
      containsAll(['u.Work', 'u.Count', 'onPluginStart', 'label']),
    );
    expect(index.completions('main.eps'), isNot(contains('local')));
    expect(
      index.completions('main.py'),
      containsAll(['helper.Work', 'run', 'value']),
    );
    expect(index.issues, isEmpty);
  });
  test('relative imports, root escapes and ambiguity are explicit', () {
    final index = SourceWorkspaceIndex({
      'pkg/main.py':
          'from .util import Work\nfrom . import util as u\nfrom ...escape import x',
      'pkg/util.py': 'def Work():\n pass',
      'main.eps': 'import util;',
      'util.eps': 'const X=1;',
      'util.py': 'X=1',
    });
    expect(index.completions('pkg/main.py'), containsAll(['Work', 'u.Work']));
    expect(
      index.issues.map((e) => e.code),
      containsAll(['SOURCE_IMPORT_OUTSIDE_ROOT', 'SOURCE_IMPORT_AMBIGUOUS']),
    );
  });
  test('Lua long comments/strings and dynamic require are not imports', () {
    final index = SourceWorkspaceIndex({
      'main.lua':
          '--[=[\nrequire("../bad")\n]=]\nlocal s=[[require("../bad")]]\nlocal u=require("util")\nrequire("../bad" .. suffix)',
      'util.lua': 'function Work()\nend',
    });
    expect(index.issues, isEmpty);
    expect(index.completions('main.lua'), contains('u.Work'));
  });
  test('literal search preserves Unicode offsets, CRLF and result limits', () {
    final index = SourceWorkspaceIndex({
      'main.py': 'İ 한글\r\n[x] = "한글"\r\n${'a\n' * 600}',
    });
    final hit = index.search('[x]').single;
    expect(hit.line, 2);
    expect(hit.column, 1);
    expect(hit.offset, 6);
    expect(index.search('한글'), hasLength(2));
    expect(index.search('a'), hasLength(500));
    expect(index.search('[').single.offset, 6);
    expect(index.search(''), isEmpty);
  });
  test('rejects traversal, ambiguous Windows paths and oversized input', () {
    for (final path in [
      '../a.py',
      'C:/a.py',
      'a\\b.py',
      'CON.py',
      'a/./b.py',
      'a.txt',
      'a//b.py',
    ]) {
      expect(() => SourcePaths.relative(path), throwsFormatException);
    }
    expect(
      () => SourceWorkspaceIndex({'main.py': 'a' * (1024 * 1024 + 1)}),
      throwsFormatException,
    );
  });
}
