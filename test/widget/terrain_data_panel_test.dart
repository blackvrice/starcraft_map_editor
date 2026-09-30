import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_editor_terrain.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/terrain_data_panel.dart';
import '../fixtures/editor_terrain_fixture.dart';

void main() {
  for (final language in ['en', 'ko']) {
    testWidgets('read-only terrain status is localized in $language', (
      tester,
    ) async {
      final report = const ChkEditorTerrainDecoder().decode(
        document([
          part('DIM ', [2, 0, 1, 0]),
          part('TILE', [0, 0, 0, 0]),
          part('MTXM', [1, 0, 0, 0]),
          part('ISOM', [0]),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ColoredBox(
                color: Colors.black,
                child: TerrainDataPanel(report: report),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('terrain-data-panel')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(language == 'ko' ? '크기 불일치' : 'Size mismatch'),
        findsOneWidget,
      );
      expect(
        find.textContaining(language == 'ko' ? '차이: 1칸' : 'differ in 1 cells'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
