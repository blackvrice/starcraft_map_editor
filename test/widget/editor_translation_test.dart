import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_parser.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/euddraft_diagnostic_parser.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_diagnostic_parser.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/localization/editor_message_localization.dart';
import 'package:starcraft_map_editor/presentation/settings/player_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/settings_surface.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_source_editor.dart';

import '../fixtures/localization_fixture.dart';

Widget localized(Widget child, {String language = 'ko'}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));
  final en = lookupAppLocalizations(const Locale('en'));

  test(
    'all editor ARB IDs resolve in both languages with English fidelity',
    () {
      final english =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final korean =
          jsonDecode(File('lib/l10n/app_ko.arb').readAsStringSync())
              as Map<String, dynamic>;
      final placeholders = RegExp(r'\{value\d+\}');
      for (final entry in english.entries.where(
        (e) => e.key.startsWith('editor'),
      )) {
        final template = entry.value as String;
        expect(korean.containsKey(entry.key), isTrue, reason: entry.key);
        final count = placeholders.allMatches(template).length;
        final values = List.generate(count, (i) => 'argument-$i');
        var expected = template;
        for (var i = 0; i < count; i++) {
          expected = expected.replaceAll('{value$i}', values[i]);
        }
        expect(
          resolveEditorMessage(en, entry.key, values),
          expected,
          reason: entry.key,
        );
        expect(
          resolveEditorMessage(ko, entry.key, values),
          isNotNull,
          reason: entry.key,
        );
        expect(
          resolveEditorMessage(ko, entry.key, values),
          isNot(contains('{value')),
          reason: entry.key,
        );
        expect(
          resolveEditorMessage(ko, entry.key, [...values, 'extra']),
          isNull,
          reason: '${entry.key} must reject unexpected arguments',
        );
      }
      expect(resolveEditorMessage(ko, 'unknown-id', []), isNull);
      expect(resolveEditorMessage(ko, 'editorPlayer', []), isNull);
    },
  );

  test('CHK diagnostics retain English, code, section and raw details', () {
    final result = const RawChkParser().parse(Uint8List.fromList([1, 2, 3]));
    final diagnostic = result.diagnostics.single;
    expect(
      diagnostic.messageId,
      'editorTheCHKSectionHeaderIsTruncatedAtByteOffset',
    );
    expect(diagnostic.messageArguments, ['0']);
    expect(
      localizedDiagnosticMessage(ko, diagnostic),
      '바이트 오프셋 0에서 CHK 섹션 헤더가 잘렸습니다.',
    );
    expect(localizedDiagnosticRemediation(ko, diagnostic), contains('읽기 전용'));
    expect(
      diagnostic.message,
      'The CHK section header is truncated at byte offset 0.',
    );
    expect(diagnostic.code, 'CHK_TRUNCATED_HEADER');
    expect(diagnostic.rawDetails, contains('availableHeaderBytes=3'));
    expect(localizedDiagnosticMessage(en, diagnostic), diagnostic.message);
  });

  test(
    'unknown IDs and compiler source output are never guessed or translated',
    () {
      const unknown = EditorDiagnostic(
        code: 'FUTURE_CODE',
        message: 'Map opened',
        messageId: 'future-id',
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.application,
      );
      expect(localizedDiagnosticMessage(ko, unknown), 'Map opened');
      final external = const EuddraftDiagnosticParser().parseLine(
        channel: EudCompilerOutputChannel.stderr,
        text: '[Error 1] Module "C:\\한글\\main.eps" Line 3 : Map opened',
      )!;
      expect(localizedDiagnosticMessage(ko, external), 'Map opened');
      expect(external.filePath, r'C:\한글\main.eps');
      expect(external.rawDetails, contains('Line 3 : Map opened'));
      expect(
        localizedDiagnosticRemediation(ko, external),
        contains('epScript'),
      );
    },
  );

  test('legacy validation uses specific templates before generic labels', () {
    expect(
      translateEditorText(ko, 'Player 1 has 2 start locations.'),
      '플레이어 1의 시작 위치가 2개 있습니다.',
    );
    expect(
      translateEditorText(
        ko,
        'FormatException: Mineral cost requires a nonnegative integer.',
      ),
      '미네랄 비용에는 음수가 아닌 정수가 필요합니다.',
    );
    expect(
      translateEditorText(
        ko,
        'IDs must be between 1 and 8, in ascending ranges.',
      ),
      contains('1~8'),
    );
    expect(
      translateEditorText(ko, 'Unrecognized native log'),
      'Unrecognized native log',
    );
  });

  for (final name in [
    'map',
    'players',
    'forces',
    'units',
    'availability',
    'upgrades',
    'tech',
    'resources',
    'briefing-properties',
    'tools',
    'source',
  ]) {
    testWidgets('Korean $name screen fits a narrow Windows-sized viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = LocalizationFixture();
      addTearDown(fixture.dispose);
      final screen = fixture.screens.firstWhere((s) => s.name == name);
      await tester.pumpWidget(localized(screen.widget));
      await tester.pumpAndSettle();
      expect(find.text(screen.heading), findsOneWidget);
      if (name == 'map') {
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('map-information-title')))
              .controller!
              .text,
          'Map',
        );
      }
      if (name == 'resources') expect(find.textContaining('Map'), findsWidgets);
      if (name == 'tools') {
        expect(
          find.textContaining('EUD_TOOL_COMPANION_MISSING'),
          findsOneWidget,
        );
        expect(
          find.text('missing=lib/freezeMpq.pyd; stdout=Map opened'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'language switch preserves player draft and semantic discard/undo actions',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = LocalizationFixture();
      addTearDown(fixture.dispose);
      Widget page() => SettingsPageScope(
        reportDraft: (_) {},
        child: PlayerSettingsDialog(controller: fixture.editing),
      );
      await tester.pumpWidget(localized(page()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('player-settings-owner')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('컴퓨터 (5)').last);
      await tester.pumpAndSettle();
      await tester.pumpWidget(localized(page(), language: 'en'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const Key('player-settings-owner')),
            )
            .value,
        5,
      );
      expect(find.byKey(const Key('settings-undo')), findsOneWidget);
      expect(find.byKey(const Key('settings-discard')), findsOneWidget);
      await tester.pumpWidget(localized(page()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('player-settings-apply')));
      await tester.pumpAndSettle();
      expect(fixture.editing.canUndo, isTrue);
      expect(find.text('실행 취소: 플레이어 설정 편집'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-undo')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const Key('player-settings-owner')),
            )
            .value,
        6,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long source path fits without translating code or paths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = LocalizationFixture();
    addTearDown(fixture.dispose);
    final path = 'C:\\${List.filled(10, '긴 소스 폴더').join('\\')}\\main.eps';
    fixture.sources.open(sourcePath: path, text: '// Map opened');
    await tester.pumpWidget(
      localized(
        EudSourceEditor(
          document: fixture.sources.state.document!,
          sourceController: fixture.sources,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(path), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('eud-source-editor')))
          .controller!
          .text,
      '// Map opened',
    );
    expect(tester.takeException(), isNull);
  });
}
