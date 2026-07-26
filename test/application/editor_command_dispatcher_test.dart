import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/commands/editor_command_dispatcher.dart';

void main() {
  test('dispatches registered commands', () async {
    var invocationCount = 0;
    final dispatcher = EditorCommandDispatcher({
      EditorCommandId.openMap: () {
        invocationCount++;
      },
    });

    expect(dispatcher.canDispatch(EditorCommandId.openMap), isTrue);

    await dispatcher.dispatch(EditorCommandId.openMap);

    expect(invocationCount, 1);
  });

  test('ignores unavailable commands', () async {
    final dispatcher = EditorCommandDispatcher();

    expect(dispatcher.canDispatch(EditorCommandId.buildEud), isFalse);
    await dispatcher.dispatch(EditorCommandId.buildEud);
  });
}
