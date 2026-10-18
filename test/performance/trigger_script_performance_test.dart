import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import '../fixtures/trigger_script_fixture.dart';

void main() {
  test(
    '512 ordinary records convert without per-slot record-copy amplification',
    () {
      final base = scriptDocument();
      final records = List.generate(512, (_) => scriptRecord(base));
      final clock = Stopwatch()..start();
      final snapshot = TriggerScriptSnapshot(scriptDocument(records: records));
      var program = snapshot.initial;
      for (final language in TriggerScriptLanguage.values) {
        final text = snapshot.format(program, language);
        program = snapshot.parse(text, language);
        expect(program.records.length, 512);
        expect(program.sameMeaning(snapshot.initial), isTrue);
      }
      clock.stop();
      expect(
        clock.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: 'Debug smoke ceiling, not a release responsiveness guarantee.',
      );
      // ignore: avoid_print
      print(
        'TRIGGER_SCRIPT_SMOKE records=512 languages=3 elapsedMs=${clock.elapsedMilliseconds}',
      );
    },
  );
}
