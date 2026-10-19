import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_source_translation_gateway.dart';
import 'package:starcraft_map_editor/application/ports/trigger_script_gateway.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_source_editor.dart';

class _Files implements TriggerScriptFiles {
  final saved = <String>[];
  @override
  Future<TriggerScriptFile?> open() async => const TriggerScriptFile(
    'C:/sources/main.eps',
    'function onPluginStart() {\n}\n',
    TriggerScriptLanguage.epScript,
  );
  @override
  Future<String?> saveNew(String text, TriggerScriptLanguage language) async {
    saved.add(text);
    return 'C:/saved/source${saved.length}.${language.extension}';
  }
}

class _Translator implements EudSourceTranslationGateway {
  @override
  void cancel() {}
  @override
  Future<EudSourceTranslation> toPython(String source) async =>
      const EudSourceTranslation(
        source:
            'from eudplib import *\n@EUDFunc\ndef onPluginStart():\n    pass\n',
        toolVersion: 'fixture',
        rawLog: '',
      );
}

void main() {
  for (final (width, locale) in [
    (600.0, const Locale('ko')),
    (1200.0, const Locale('en')),
  ]) {
    testWidgets(
      'native source selection/files and read-only translation at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final files = _Files();
        final c = EudSourceController(files: files, translator: _Translator());
        c.createUntitled();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: StreamBuilder<EudSourceState>(
                stream: c.changes,
                builder: (context, _) => EudSourceEditor(
                  document: c.state.document!,
                  sourceController: c,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('eud-source-language')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Python').last);
        await tester.pumpAndSettle();
        expect(c.state.document!.language, TriggerScriptLanguage.python);
        await tester.tap(find.byKey(const Key('ep-script-example')));
        await tester.pumpAndSettle();
        expect(c.state.document!.text, contains('from eudplib import *'));
        await tester.tap(find.byKey(const Key('eud-source-save')));
        await tester.pumpAndSettle();
        expect(c.state.document!.isDirty, isFalse);
        await tester.tap(find.byKey(const Key('eud-source-open')));
        await tester.pumpAndSettle();
        final original = c.state.document;
        await tester.tap(find.byKey(const Key('eud-source-translate')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.translate).last);
        await tester.pumpAndSettle();
        expect(find.textContaining('from eudplib import *'), findsOneWidget);
        expect(c.state.document, same(original));
        await tester.tap(find.byKey(const Key('eud-translation-save')));
        await tester.pumpAndSettle();
        expect(files.saved, hasLength(2));
        expect(c.state.document, same(original));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
