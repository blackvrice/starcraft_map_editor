import 'dart:async';

enum EditorCommandId { openMap, saveAs, buildEud }

typedef EditorCommandHandler = FutureOr<void> Function();

class EditorCommandDispatcher {
  EditorCommandDispatcher([
    Map<EditorCommandId, EditorCommandHandler>? handlers,
  ]) : _handlers = {...?handlers};

  final Map<EditorCommandId, EditorCommandHandler> _handlers;

  bool canDispatch(EditorCommandId command) => _handlers.containsKey(command);

  void register(EditorCommandId command, EditorCommandHandler handler) {
    _handlers[command] = handler;
  }

  void unregister(EditorCommandId command) {
    _handlers.remove(command);
  }

  Future<void> dispatch(EditorCommandId command) async {
    final handler = _handlers[command];
    if (handler == null) {
      return;
    }

    await handler();
  }
}
