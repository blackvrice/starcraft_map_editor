import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/commands/editor_command_dispatcher.dart';

void main() {
  test('dispatches registered commands', () async {
    var invocationCount = 0;
    Object? receivedArgument;
    final dispatcher = EditorCommandDispatcher({
      EditorCommandId.openMap: (argument) {
        invocationCount++;
        receivedArgument = argument;
      },
    });

    expect(dispatcher.canDispatch(EditorCommandId.openMap), isTrue);

    await dispatcher.dispatch(
      EditorCommandId.openMap,
      argument: r'C:\Maps\Test.scx',
    );

    expect(invocationCount, 1);
    expect(receivedArgument, r'C:\Maps\Test.scx');
  });

  test('ignores unavailable commands', () async {
    final dispatcher = EditorCommandDispatcher();

    expect(dispatcher.canDispatch(EditorCommandId.buildEud), isFalse);
    await dispatcher.dispatch(EditorCommandId.buildEud);
  });
}
