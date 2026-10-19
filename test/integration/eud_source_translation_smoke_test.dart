import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/bundled_eud_tool.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_source_translation_gateway.dart';

const freeSource = '''function onPluginStart() {
    var count = 0;
    for (var i = 0; i < 3; i++) {
        count += 1;
    }
    if (count == 3) {
        SetMemory(0x6509B0, Add, 0);
    }
}
''';

void main() {
  final helper = Platform.environment['EUD_TRANSLATE_HELPER_PATH'];
  test(
    'managed compiler translates variables, loops and conditionals without running source',
    () async {
      final gateway = ProcessEudSourceTranslationGateway(
        helperPath: helper!,
        bundlePath: BundledEudTool.pathForExecutable(helper),
      );
      final result = await gateway.toPython(freeSource);
      expect(result.source, contains('from eudplib import *'));
      expect(result.source, contains('def onPluginStart():'));
      expect(result.source, contains('DoActions(SetMemory'));
      expect(result.source, contains('EUDIf()'));
      expect(result.toolVersion, 'euddraft-0.10.2.5/epScript');
      expect(result.rawLog, isEmpty);
      await expectLater(
        gateway.toPython('function broken( {'),
        throwsStateError,
      );
      await expectLater(
        gateway.toPython('function onPluginStart() { UnknownExternalApi(); }'),
        throwsStateError,
      );
      final cancelled = gateway.toPython(freeSource);
      gateway.cancel();
      await expectLater(cancelled, throwsStateError);
      // A cancelled request must not poison the next independent translation.
      expect((await gateway.toPython(freeSource)).source, result.source);
      final timeout = ProcessEudSourceTranslationGateway(
        helperPath: helper,
        bundlePath: BundledEudTool.pathForExecutable(helper),
        timeout: Duration.zero,
      );
      await expectLater(timeout.toPython(freeSource), throwsStateError);
    },
    skip: helper == null
        ? 'Set EUD_TRANSLATE_HELPER_PATH to the managed helper.'
        : false,
  );
}
