import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import '../../fixtures/basic_editing_fixture.dart';
import '../../fixtures/trigger_script_fixture.dart';

void main() {
  for (final language in TriggerScriptLanguage.values) {
    group(language.name, () {
      test(
        'no-op is byte exact, including slot gaps, flags, owners and reserved bytes',
        () {
          final s = TriggerScriptSnapshot(scriptDocument());
          final source = s.format(s.initial, language),
              parsed = s.parse(source, language);
          expect(parsed.sameMeaning(s.initial), isTrue);
          expect(parsed.opaqueDeletions, 0);
          expect(parsed.triggers.single.bytes, s.original.single.bytes);
          expect(
            source,
            contains('ActionWait(4, ${language.boolean(true)}, 1000)'),
          );
        },
      );
      test(
        'a source without a leading comment has the same declaration model',
        () {
          final s = TriggerScriptSnapshot(scriptDocument());
          final text = s.format(s.initial, language);
          expect(
            s
                .parse(text.substring(text.indexOf('\n') + 1), language)
                .sameMeaning(s.initial),
            isTrue,
          );
        },
      );
      test('one argument changes only its four bytes', () {
        final s = TriggerScriptSnapshot(scriptDocument());
        final source = s
            .format(s.initial, language)
            .replaceFirst(', 1000)', ', 2000)');
        final parsed = s.parse(source, language).triggers.single.bytes;
        final allowed = {for (var i = 0; i < 4; i++) 320 + 4 * 32 + 12 + i};
        for (var i = 0; i < 2400; i++) {
          if (!allowed.contains(i)) {
            expect(parsed[i], s.original.single.bytes[i], reason: '$i');
          }
        }
        expect(parsed, isNot(s.original.single.bytes));
      });
      test('unknown/EUDX slot is a bound reference; deletion is counted', () {
        final doc = scriptDocument();
        final record = scriptRecord(doc);
        final bytes = [...record.bytes]..[18] = 0x53;
        final s = TriggerScriptSnapshot(
          scriptDocument(records: [ChkTrigger(bytes)]),
        );
        final source = s.format(s.initial, language);
        expect(source, contains('RawCondition(0)'));
        expect(s.parse(source, language).triggers.single.bytes, bytes);
        final changed = source.replaceFirst('RawCondition(0)', '');
        expect(s.parse(changed, language).opaqueDeletions, 1);
        final header = source.substring(0, source.indexOf('\nMapTrigger'));
        expect(s.parse(header, language).opaqueDeletions, 2);
        expect(
          () => s.parse(
            source.replaceFirst('RawCondition(0)', 'RawCondition(1)'),
            language,
          ),
          throwsA(isA<TriggerScriptDiagnostic>()),
        );
      });
      test(
        'new and reordered records retain explicit owners, order and disabled states',
        () {
          final s = TriggerScriptSnapshot(
            scriptDocument(
              records: [
                scriptRecord(scriptDocument()),
                scriptRecord(scriptDocument()).withEnabled(false),
              ],
            ),
          );
          final program = TriggerScriptProgram([
            TriggerScriptRecord(1, s.original[1]),
            TriggerScriptRecord(0, s.original[0]),
            TriggerScriptRecord(null, ChkTrigger.create()),
          ], 0);
          final parsed = s.parse(s.format(program, language), language);
          expect(parsed.sameMeaning(program), isTrue);
          expect(parsed.triggers[0].enabled, isFalse);
          expect(parsed.triggers[1].bytes[2372], 2);
        },
      );
      test(
        'snapshot mismatch, duplicate source/slot/owner and falsey integers reject',
        () {
          final s = TriggerScriptSnapshot(scriptDocument()),
              source = s.format(s.initial, language);
          for (final bad in [
            source.replaceFirst(s.fingerprint, '0' * 64),
            source + source.substring(source.indexOf('MapTrigger(')),
            source.replaceFirst('Owners(0)', 'Owners(0, 0)'),
            source.replaceFirst(
              'Enabled(${language.boolean(true)})',
              'Enabled(0)',
            ),
            source.replaceFirst(
              'ConditionAlways(0, ${language.boolean(true)})',
              'ConditionAlways(0, ${language.boolean(true)}), ConditionAlways(0, ${language.boolean(true)})',
            ),
            source.replaceFirst(', 1000)', ', 4294967296)'),
            source.replaceFirst(', 1000)', ', -1)'),
          ]) {
            expect(
              () => s.parse(bad, language),
              throwsA(isA<TriggerScriptDiagnostic>()),
            );
          }
        },
      );
    });
  }
  test(
    'three-language canonical conversion preserves model and all map bytes',
    () {
      final doc = scriptDocument(), s = TriggerScriptSnapshot(scriptDocument());
      var program = s.initial;
      for (var cycle = 0; cycle < 3; cycle++) {
        for (final language in TriggerScriptLanguage.values) {
          program = s.parse(s.format(program, language), language);
          expect(program.sameMeaning(s.initial), isTrue);
        }
      }
      expect(
        const RawChkEncoder().encode(doc),
        const RawChkEncoder().encode(s.document),
      );
    },
  );
  for (final action in [false, true]) {
    for (final opcode
        in action ? TriggerOpcodes.actions : TriggerOpcodes.conditions) {
      test(
        'all portable fields: ${action ? "action" : "condition"} ${opcode.id}',
        () {
          final doc = RawChkDocument(
            sections: [
              basicSection('TRIG', []),
              basicSection('MRGN', List.filled(5100, 0)),
              basicSection('STR ', [1, 0, 4, 0, 65, 0]),
              basicSection('UPRP', List.filled(1280, 0)),
            ],
            sourceLength: 0,
          );
          final slot = ChkTrigger.makeSlot(action, opcode, {
            for (final arg in opcode.arguments)
              arg.name: arg.choices.isNotEmpty
                  ? arg.choices.keys.first
                  : arg.reference == 'script'
                  ? 0x54534554
                  : {'location', 'string', 'property'}.contains(arg.reference)
                  ? 1
                  : 0,
          }, doc);
          final record = ChkTrigger.create().withSlot(
            action,
            action ? 63 : 15,
            slot,
          );
          final source = doc.replaceSection(
            0,
            basicSection('TRIG', record.bytes),
          );
          final s = TriggerScriptSnapshot(source);
          expect(s.portable(action, slot), isTrue);
          for (final language in TriggerScriptLanguage.values) {
            final text = s.format(s.initial, language);
            expect(s.parse(text, language).triggers.single.bytes, record.bytes);
          }
        },
      );
    }
  }
  test(
    'missing references stay raw and cannot silently normalize legacy values',
    () {
      final doc = scriptDocument(), bytes = [...scriptRecord(doc).bytes];
      bytes[320 + 26] = 9;
      bytes[320 + 4] = 0xff;
      bytes[320 + 5] = 0xff;
      final s = TriggerScriptSnapshot(
        scriptDocument(records: [ChkTrigger(bytes)]),
      );
      final text = s.format(s.initial, TriggerScriptLanguage.python);
      expect(text, contains('RawAction(0)'));
      expect(
        s.parse(text, TriggerScriptLanguage.python).triggers.single.bytes,
        bytes,
      );
    },
  );
  test('missing, duplicate and truncated TRIG are refused without repair', () {
    final doc = scriptDocument();
    final index = doc.sections.indexWhere((s) => s.name == 'TRIG');
    for (final bad in [
      RawChkDocument(
        sections: doc.sections.where((s) => s.name != 'TRIG').toList(),
        sourceLength: 0,
      ),
      doc.appendSection(doc.sections[index]),
      doc.replaceSection(index, basicSection('TRIG', [0])),
    ]) {
      expect(() => TriggerScriptSnapshot(bad), throwsFormatException);
    }
  });
  test(
    'input/record/depth/node budgets and unsupported host syntax fail closed',
    () {
      final s = TriggerScriptSnapshot(scriptDocument()),
          header = s.format(s.initial, TriggerScriptLanguage.python);
      for (final tail in [
        'import os',
        'exec("x")',
        'require("io")',
        'for i in range(3): pass',
        'Enabled(1 + 2)',
        'x = 1',
        'MapTrigger\n()',
        '    MapTrigger()',
        '${'f(' * 10}0${')' * 10}',
      ]) {
        expect(
          () => s.parse('$header\n$tail', TriggerScriptLanguage.python),
          throwsA(isA<TriggerScriptDiagnostic>()),
        );
      }
      expect(
        () => TriggerScriptSyntax(
          ' ' * (TriggerScriptSyntax.maximumCharacters + 1),
          TriggerScriptLanguage.lua,
        ).parse(),
        throwsA(isA<TriggerScriptDiagnostic>()),
      );
      expect(
        () => TriggerScriptSnapshot(
          scriptDocument(records: List.filled(513, ChkTrigger.create())),
        ),
        throwsA(isA<TriggerScriptDiagnostic>()),
      );
    },
  );
  test('UTF-16 diagnostics handle Korean comments, CRLF and tabs', () {
    final source = '# 한글 😀\r\n\tunsupported';
    try {
      TriggerScriptSyntax(source, TriggerScriptLanguage.python).parse();
      fail('accepted');
    } on TriggerScriptDiagnostic catch (e) {
      expect(e.position(source), (line: 2, column: 2));
      expect(source.substring(e.offset), 'unsupported');
    }
  });
}
