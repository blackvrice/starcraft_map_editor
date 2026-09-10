import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/settings_id_selection.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_upgrade_settings_editor.dart';

void main() {
  test(
    'bulk upgrade drafts are rejected atomically when a target level pair is invalid',
    () {
      RawChkSection section(String name, List<int> bytes) => RawChkSection(
        nameBytes: name.codeUnits,
        payload: bytes,
        declaredLength: bytes.length,
        sourceOffset: 0,
      );
      final source = RawChkDocument(
        sourceLength: 0,
        sections: [
          section('VER ', [206, 0]),
          section('UPGx', List.filled(794, 0)),
          section('PUPx', List.filled(2318, 0)..[1464] = 2),
        ],
      );
      final draft = <UpgradeSettingKey, int>{
        (0, null, ChkUpgradeField.start): 1,
        (0, null, ChkUpgradeField.minerals): 100,
      };
      final copies = copySettingsDraft(
        draft,
        (key) => key.$1 == 0,
        (key, id) => (id, key.$2, key.$3),
        {1, 2},
      );
      const editor = ChkUpgradeSettingsEditor();
      expect(
        () => editor.edit(source, {...draft, ...copies}),
        throwsStateError,
      );
      expect(source.isDirty, isFalse);
      expect(source.sections[1].payload, List.filled(794, 0));
      draft[(0, null, ChkUpgradeField.maximum)] = 2;
      final valid = copySettingsDraft(
        draft,
        (key) => key.$1 == 0,
        (key, id) => (id, key.$2, key.$3),
        {1, 2},
      );
      expect(editor.edit(source, {...draft, ...valid}).length, 2);
    },
  );
  test('explicit ID selections deduplicate and bound ranges', () {
    expect(parseSettingsIds('1, 3-8', 9, minimum: 1), {1, 3, 4, 5, 6, 7, 8});
    expect(
      () => parseSettingsIds('0, 1', 9, minimum: 1),
      throwsFormatException,
    );
    expect(parseSettingsIds(' 0, 2-4, 3, 227 ', 228), {0, 2, 3, 4, 227});
    expect(parseSettingsIds('0-43', 44).length, 44);
    expect(() => parseSettingsIds('1', 44).add(2), throwsUnsupportedError);
    for (final input in [
      '',
      ' ',
      '-1',
      '3-1',
      '1,',
      ',1',
      '44',
      '0-99999999',
      '1.5',
      '1-2-3',
      'all',
      '1' * 513,
    ]) {
      expect(
        () => parseSettingsIds(input, 44),
        throwsFormatException,
        reason: input,
      );
    }
  });
  test(
    'draft copying snapshots only source fields and preserves caller state',
    () {
      final draft = <(int, int?, String), String>{
        (0, null, 'cost'): '100',
        (0, 0, 'allowed'): '1',
        (0, 1, 'allowed'): '0',
        (1, null, 'energy'): '50',
      };
      final copied = copySettingsDraft(
        draft,
        (key) => key.$1 == 0 && (key.$2 == null || key.$2 == 0),
        (key, id) => (id, key.$2, key.$3),
        {1, 2},
      );
      expect(copied, {
        (1, null, 'cost'): '100',
        (2, null, 'cost'): '100',
        (1, 0, 'allowed'): '1',
        (2, 0, 'allowed'): '1',
      });
      expect(draft.length, 4);
      draft.addAll(copied);
      expect(draft[(1, null, 'energy')], '50');
      expect(draft[(0, 1, 'allowed')], '0');
    },
  );
}
