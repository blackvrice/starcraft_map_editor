import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/isolate_trigger_script_gateway.dart';
import '../fixtures/trigger_script_fixture.dart';

void main() {
  test(
    'isolated parse converts all three languages and validates meaning without execution',
    () async {
      final gateway = IsolateTriggerScriptGateway(), doc = scriptDocument();
      var source = TriggerScriptSnapshot(doc).format(
        TriggerScriptSnapshot(doc).initial,
        TriggerScriptLanguage.epScript,
      );
      var language = TriggerScriptLanguage.epScript;
      for (final target in [
        TriggerScriptLanguage.python,
        TriggerScriptLanguage.lua,
        TriggerScriptLanguage.epScript,
      ]) {
        final result = await gateway.analyze(
          operationId: target.name,
          document: doc,
          language: language,
          source: source,
          target: target,
        );
        expect(result.isSuccess, isTrue, reason: '${result.diagnostic}');
        expect(
          result.program!.triggers.single.bytes,
          TriggerScriptSnapshot(doc).original.single.bytes,
        );
        source = result.generated!;
        language = target;
      }
    },
  );
  test(
    'cancel, timeout and malformed syntax return diagnostics without partial results',
    () async {
      final doc = scriptDocument();
      final gateway = IsolateTriggerScriptGateway();
      final pending = gateway.analyze(
        operationId: 'cancel',
        document: doc,
        language: TriggerScriptLanguage.python,
      );
      gateway.cancel('cancel');
      expect((await pending).diagnostic!.code, 'SCRIPT_CANCELLED');
      final timeout = await IsolateTriggerScriptGateway(timeout: Duration.zero)
          .analyze(
            operationId: 'timeout',
            document: doc,
            language: TriggerScriptLanguage.lua,
          );
      expect(timeout.diagnostic!.code, 'SCRIPT_TIMEOUT');
      final bad = await gateway.analyze(
        operationId: 'bad',
        document: doc,
        language: TriggerScriptLanguage.python,
        source: 'open("secret")',
      );
      expect(bad.isSuccess, isFalse);
      expect(bad.program, isNull);
      expect(bad.diagnostic!.code, 'SCRIPT_SNAPSHOT');
    },
  );
}
