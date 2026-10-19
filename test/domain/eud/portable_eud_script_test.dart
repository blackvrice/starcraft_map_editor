import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/portable_eud_script.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script_syntax.dart';

const example = '''// original Korean comment: 원문
function onPluginStart() {
    SetMemory(0x6509B0, Add, 0);
    DisplayText("hello 한글");
}
function beforeTriggerExec() {
    SetDeaths(P1, SetTo, 10, 0);
}
function afterTriggerExec() {
}
''';

void main() {
  test(
    'ordered hooks and action semantics round trip across all three languages',
    () {
      final model = PortableEudScript.parse(
        example,
        TriggerScriptLanguage.epScript,
      );
      final canonical = model.format(TriggerScriptLanguage.python);
      expect(canonical, contains('@EUDFunc\ndef onPluginStart():'));
      expect(canonical, contains('DoActions(SetMemory(6621616, Add, 0))'));
      expect(canonical, contains('    pass'));
      for (final a in TriggerScriptLanguage.values) {
        for (final b in TriggerScriptLanguage.values) {
          final first = PortableEudScript.parse(model.convert(a), a);
          final second = PortableEudScript.parse(first.convert(b), b);
          expect(second.format(TriggerScriptLanguage.python), canonical);
        }
      }
      expect(example, contains('// original'));
    },
  );

  for (final name in PortableEudScript.actions) {
    test('portable action $name keeps call identity and values', () {
      final model = PortableEudScript.parse(
        'function onPluginStart() {\n    $name(0, EPD(100), true);\n}\n',
        TriggerScriptLanguage.epScript,
      );
      for (final language in TriggerScriptLanguage.values) {
        final text = model.convert(language);
        expect(
          PortableEudScript.parse(
            text,
            language,
          ).hooks.values.single.single.name,
          name,
        );
      }
    });
  }

  for (final source in [
    'function onPluginStart() { SetMemory(1, Add, 2); }',
    'function badHook() {\n}\n',
    'function onPluginStart() {\n    var x = 1;\n}\n',
    'function onPluginStart() {\n    exec("bad");\n}\n',
    'function onPluginStart() {\n    SetMemory(1, Unknown, 2);\n}\n',
    'function onPluginStart() {\n    SetMemory(1, Add, eval("x"));\n}\n',
    'function onPluginStart() {\n    SetMemory(1, Add, 1 + 2);\n}\n',
    'function onPluginStart() {\n    SetMemory(1, Add, 2);\n',
    'function onPluginStart() {\n}\nfunction onPluginStart() {\n}\n',
    'import x;\nfunction onPluginStart() {\n}\n',
  ]) {
    test('unsupported EPS is rejected without partial output: $source', () {
      expect(
        () => PortableEudScript.parse(source, TriggerScriptLanguage.epScript),
        throwsA(isA<TriggerScriptDiagnostic>()),
      );
    });
  }
  for (final source in [
    'from eudplib import *\ndef onPluginStart():\n    SetMemory(1, Add, 2)\n',
    'from eudplib import *\n@EUDFunc\ndef onPluginStart():\n    SetMemory(1, Add, 2)\n',
    'from os import *\n@EUDFunc\ndef onPluginStart():\n    pass\n',
    'from eudplib import *\n@EUDFunc\ndef onPluginStart():\n    exec("bad")\n',
    'from eudplib import *\n@EUDFunc\ndef onPluginStart():\n        DoActions(SetMemory(1, Add, 2))\n',
  ]) {
    test('reject unrepresentable Python semantics: $source', () {
      expect(
        () => PortableEudScript.parse(source, TriggerScriptLanguage.python),
        throwsA(isA<TriggerScriptDiagnostic>()),
      );
    });
  }
  test('size limits and diagnostic positions are bounded', () {
    expect(
      () => PortableEudScript.parse(
        'x' * (1024 * 1024 + 1),
        TriggerScriptLanguage.epScript,
      ),
      throwsA(isA<TriggerScriptDiagnostic>()),
    );
  });
  test(
    'Python diagnostics map indentation and CRLF to exact UTF-16 position',
    () {
      const source =
          'from eudplib import *\r\n@EUDFunc\r\ndef onPluginStart():\r\n    DoActions(SetMemory(1, Add, 2))\r\n    DoActions(Unknown(1))\r\n';
      try {
        PortableEudScript.parse(source, TriggerScriptLanguage.python);
        fail('must reject');
      } on TriggerScriptDiagnostic catch (e) {
        expect(e.offset, source.indexOf('Unknown'));
        expect(e.position(source), (line: 5, column: 15));
      }
      expect(
        () => PortableEudScript.parse(
          'from eudplib import *\n@EUDFunc\ndef onPluginStart():\n',
          TriggerScriptLanguage.python,
        ),
        throwsA(isA<TriggerScriptDiagnostic>()),
      );
    },
  );
}
