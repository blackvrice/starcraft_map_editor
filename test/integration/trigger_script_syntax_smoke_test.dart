import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import '../../test/fixtures/basic_editing_fixture.dart';

void main() {
  final python = Platform.environment['TRIGGER_SYNTAX_PYTHON'],
      dll = Platform.environment['TRIGGER_SYNTAX_EPS_DLL'],
      luac = Platform.environment['TRIGGER_SYNTAX_LUAC'];
  test(
    'all supported declarations pass real Python, epScript and Lua syntax frontends',
    () async {
      final base = RawChkDocument(
        sections: [
          basicSection('TRIG', []),
          basicSection('MRGN', List.filled(5100, 0)),
          basicSection('STR ', [1, 0, 4, 0, 65, 0]),
          basicSection('UPRP', List.filled(1280, 0)),
        ],
        sourceLength: 0,
      );
      final records = <ChkTrigger>[];
      for (final action in [false, true]) {
        for (final opcode
            in action ? TriggerOpcodes.actions : TriggerOpcodes.conditions) {
          records.add(
            ChkTrigger.create().withSlot(
              action,
              0,
              ChkTrigger.makeSlot(action, opcode, {
                for (final a in opcode.arguments)
                  a.name: a.choices.isNotEmpty
                      ? a.choices.keys.first
                      : a.reference == 'script'
                      ? 0x54534554
                      : {'string', 'location', 'property'}.contains(a.reference)
                      ? 1
                      : 0,
              }, base),
            ),
          );
        }
      }
      final snapshot = TriggerScriptSnapshot(
        base.replaceSection(
          0,
          basicSection('TRIG', ChkTriggers.encode(records)),
        ),
      );
      final process = await Process.start(python!, [
        '-I',
        File('tool/trigger_script_syntax/verify.py').absolute.path,
        '--eps-dll',
        dll!,
        '--luac',
        luac!,
      ], runInShell: false);
      final stdout = process.stdout.transform(utf8.decoder).join(),
          stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(
        jsonEncode({
          for (final language in TriggerScriptLanguage.values)
            language.name: snapshot.format(snapshot.initial, language),
          'apis': [
            'MapScript',
            'MapTrigger',
            'Source',
            'New',
            'Owners',
            'Enabled',
            'Conditions',
            'Actions',
            'RawCondition',
            'RawAction',
            ...TriggerScriptSnapshot.conditionNames.keys,
            ...TriggerScriptSnapshot.actionNames.keys,
          ],
        }),
      );
      await process.stdin.close();
      final exit = await process.exitCode.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      expect(exit, 0, reason: '${await stdout}\n${await stderr}');
      expect(await stdout, contains('"sourceExecution": 0'));
    },
    skip: python == null || dll == null || luac == null
        ? 'Set TRIGGER_SYNTAX_PYTHON, TRIGGER_SYNTAX_EPS_DLL and TRIGGER_SYNTAX_LUAC.'
        : false,
  );
}
