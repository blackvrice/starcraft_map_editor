import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
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
  for (final locale in ['ko', 'en']) {
    testWidgets(
      'existing ISOM recalculation preserves flags and Undo ($locale)',
      (tester) async {
        final h = NewMapHarness();
        addTearDown(h.dispose);
        h.maps.createNew(
          NewMapOptions(width: 32, height: 32, rawTileValue: 0),
          expectedSession: null,
        );
        final c = IsomFillController(
          maps: h.maps,
          assets: () => h.assets,
          gateway: SolidSnapshotGateway(),
        );
        await c.load();
        c.apply(c.preview(terrainType: 2));
        final filled = h.maps.state.session!;
        final at = filled.rawDocument.sections.indexWhere(
          (s) => s.name == 'ISOM',
        );
        final data = ByteData.sublistView(
          filled.rawDocument.sections[at].payload,
        );
        for (var i = 0; i < data.lengthInBytes; i += 2) {
          data.setUint16(
            i,
            0x8021,
            Endian.little,
          ); // Known type 3 with editor flags.
        }
        final doc = filled.rawDocument.replaceSection(
          at,
          filled.rawDocument.sections[at].withPayload(
            data.buffer.asUint8List(),
          ),
        );
        final before = OpenedMapSession(
          extractedMap: filled.extractedMap,
          rawDocument: doc,
          metadataViews: filled.metadataViews,
          stringViews: filled.stringViews,
          terrainViews: filled.terrainViews,
          objectViews: filled.objectViews,
          sourceFingerprint: filled.sourceFingerprint,
          diagnostics: filled.diagnostics,
          resourceEdits: filled.resourceEdits,
        );
        h.maps.adoptEditedSession(before);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
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
        await tester.tap(
          find.text(
            locale == 'ko' ? '기존 ISOM 재계산' : 'Recalculate existing ISOM',
          ),
        );
        await tester.pumpAndSettle();
        expect(h.maps.state.session, same(before));
        expect(find.byKey(const Key('isom-terrain-type')), findsNothing);
        await tester.tap(
          find.text(locale == 'ko' ? '재계산한 타일 적용' : 'Apply recalculated tiles'),
        );
        await tester.pumpAndSettle();
        final after = h.maps.state.session!;
        expect(after, isNot(same(before)));
        expect(
          after.rawDocument.sections[at],
          same(before.rawDocument.sections[at]),
        );
        expect(h.maps.editHistory.undoDepth, 2);
        h.maps.editHistory.undo();
        expect(h.maps.state.session, same(before));
        h.maps.editHistory.redo();
        expect(h.maps.state.session, same(after));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
