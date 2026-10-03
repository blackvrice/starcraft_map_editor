import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/settings/visual_settings_picker.dart';

void main() {
  for (final weapons in [false, true]) {
    testWidgets(
      'named ${weapons ? 'weapon' : 'unit'} grid remains selectable without local assets',
      (tester) async {
        tester.view.physicalSize = const Size(600, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VisualSettingsPicker(
                ids: [0, 1, 2],
                selected: 0,
                label: (id) => 'Named item #$id',
                onSelected: (id) => selected = id,
                prefix: 'test-picker',
                weapons: weapons,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Named item #1'), findsOneWidget);
        await tester.tap(find.byKey(const Key('test-picker-visual-1')));
        expect(selected, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
