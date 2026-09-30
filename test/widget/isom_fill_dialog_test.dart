import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/isom_fill_dialog.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/solid_isom_fixture.dart';

void main() {
  for (final apply in [false, true]) {
    testWidgets('Korean whole map fill preview and apply/cancel ($apply)', (
      tester,
    ) async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        expectedSession: null,
      );
      final before = h.maps.state.session;
      final c = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: SolidSnapshotGateway(),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => IsomFillDialog(controller: c),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('등각 지형 채우기'), findsOneWidget);
      expect(h.maps.state.session, same(before));
      await tester.tap(find.text(apply ? '맵 전체 채우기' : '취소'));
      await tester.pumpAndSettle();
      expect(h.maps.state.session, apply ? isNot(same(before)) : same(before));
      expect(h.maps.editHistory.undoDepth, apply ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }
}
