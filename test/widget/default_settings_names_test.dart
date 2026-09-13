import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/settings/default_settings_names.dart';
import 'package:starcraft_map_editor/presentation/settings/settings_selection.dart';

void main() {
  test('unnamed slots retain IDs and custom names take precedence', () {
    expect(settingsName('Upgrade', 18, defaultUpgradeNames), 'Upgrade #18');
    expect(settingsName('Tech', 43, defaultTechNames), 'Tech #43');
    expect(settingsName('Weapon', 500, defaultWeaponNames), 'Weapon #500');
    expect(
      settingsName('Tech', 0, defaultTechNames, custom: 'My research'),
      'My research (Tech #0)',
    );
    expect(
      settingsName('Tech', 0, defaultTechNames, custom: ''),
      'Stim Packs (Tech #0)',
    );
  });

  testWidgets('default name search keeps selection and exact ID search', (
    tester,
  ) async {
    var selectionChanges = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSelection(
            prefix: 'names',
            selectorKey: const Key('names-selection'),
            count: defaultUpgradeNames.length,
            selected: 0,
            label: (id) => settingsName('Upgrade', id, defaultUpgradeNames),
            onSelected: (_) => selectionChanges++,
            scope: 'test',
          ),
        ),
      ),
    );
    final search = find.byKey(const Key('names-search'));
    final selector = find.byKey(const Key('names-selection'));
    await tester.enterText(search, 'Vehicle Plating');
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<int>>(selector).items!.single.value, 1);
    expect(selectionChanges, 0);
    await tester.enterText(search, '#18');
    await tester.pumpAndSettle();
    expect(
      tester.widget<DropdownButton<int>>(selector).items!.single.value,
      18,
    );
    expect(selectionChanges, 0);
  });
}
