import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/settings/settings_selection.dart';

void main() {
  testWidgets(
    'search does not change scope and invalid ranges never call copy',
    (tester) async {
      var selected = 0;
      Set<int>? copied;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: SettingsSelection(
                  prefix: 'test',
                  selectorKey: const Key('selector'),
                  count: 20,
                  selected: selected,
                  label: (id) => 'Unit #$id',
                  searchText: (id) => id == 12 ? 'Custom marine' : '',
                  scope: 'Player 1 only',
                  onSelected: (id) => setState(() => selected = id),
                  onCopy: (ids) {
                    copied = ids;
                    return ids.length;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('test-search')), 'MARINE');
      await tester.pump();
      expect(selected, 0);
      var selector = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('selector')),
      );
      expect(selector.items!.map((e) => e.value), [12]);
      await tester.tap(find.byKey(const Key('selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unit #12').last);
      await tester.pumpAndSettle();
      expect(selected, 12);
      await tester.enterText(find.byKey(const Key('test-search')), 'no match');
      await tester.pump();
      selector = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('selector')),
      );
      expect(selector.onChanged, isNull);
      expect(selected, 12);
      await tester.tap(find.byKey(const Key('test-bulk')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('test-range')), '2, 999');
      await tester.ensureVisible(find.byKey(const Key('test-copy')));
      await tester.tap(find.byKey(const Key('test-copy')));
      await tester.pump();
      expect(copied, isNull);
      await tester.enterText(find.byKey(const Key('test-range')), '2-4, 3');
      await tester.tap(find.byKey(const Key('test-copy')));
      await tester.pump();
      expect(copied, {2, 3, 4});
      expect(selected, 12);
    },
  );
}
