import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_search.dart';
import '../fixtures/settings_trigger_editing_fixture.dart';

void main() {
  test('10,000 records index once and run stable typed searches', () {
    final doc = editingDocument(),
        record = triggerAction(editingDocument(), 10);
    final data = withRecords(doc, List.filled(10000, record));
    final watch = Stopwatch()..start();
    final search = ChkTriggerSearch(data);
    final indexMs = watch.elapsedMilliseconds;
    watch.reset();
    for (var i = 0; i < 20; i++) {
      expect(
        search.find(
          'center view',
          reference: 'location',
          id: 64,
          action: true,
          opcode: 10,
          owner: 0,
          enabled: true,
        ),
        hasLength(10000),
      );
    }
    final queryMs = watch.elapsedMilliseconds;
    // Broad regression limits, not a release latency or real-map benchmark.
    expect(indexMs, lessThan(20000));
    expect(queryMs, lessThan(10000));
    final preview = search.replace(
      selected: {0, 9999},
      reference: 'location',
      from: 64,
      to: 2,
    );
    expect(preview.changedRecords, {0, 9999});
    expect(preview.replacements, 2);
    // ignore: avoid_print
    print(
      'trigger-search: records=10000 indexMs=$indexMs queries=20 queryMs=$queryMs',
    );
  });
}
