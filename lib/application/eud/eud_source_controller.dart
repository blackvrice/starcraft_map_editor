import 'dart:async';

import 'eud_source_document.dart';

final class EudSourceState {
  const EudSourceState({required this.document});

  const EudSourceState.closed() : document = null;

  final EudSourceDocument? document;

  bool get hasDocument => document != null;
}

final class EudSourceController {
  EudSourceController() : _state = const EudSourceState.closed();

  final StreamController<EudSourceState> _changes =
      StreamController<EudSourceState>.broadcast(sync: true);

  EudSourceState _state;
  int _untitledSequence = 0;

  EudSourceState get state => _state;
  Stream<EudSourceState> get changes => _changes.stream;

  bool createUntitled({String fileName = 'main.eps', String initialText = ''}) {
    if (_state.document != null) {
      return false;
    }
    _untitledSequence++;
    _emit(
      EudSourceState(
        document: EudSourceDocument.untitled(
          documentId: 'untitled-$_untitledSequence',
          fileName: fileName,
          initialText: initialText,
        ),
      ),
    );
    return true;
  }

  bool open({
    required String sourcePath,
    required String text,
    bool discardChanges = false,
  }) {
    final current = _state.document;
    if (current?.isDirty ?? false) {
      if (!discardChanges) {
        return false;
      }
    }
    _untitledSequence++;
    _emit(
      EudSourceState(
        document: EudSourceDocument.opened(
          documentId: 'source-$_untitledSequence',
          sourcePath: sourcePath,
          text: text,
        ),
      ),
    );
    return true;
  }

  void updateText(String text) {
    final current = _state.document;
    if (current == null) {
      throw StateError('No epScript document is open.');
    }
    final updated = current.withText(text);
    if (identical(updated, current)) {
      return;
    }
    _emit(EudSourceState(document: updated));
  }

  void markSaved({String? sourcePath}) {
    final current = _state.document;
    if (current == null) {
      throw StateError('No epScript document is open.');
    }
    _emit(EudSourceState(document: current.markSaved(savedPath: sourcePath)));
  }

  bool close({bool discardChanges = false}) {
    final current = _state.document;
    if (current == null) {
      return true;
    }
    if (current.isDirty && !discardChanges) {
      return false;
    }
    _emit(const EudSourceState.closed());
    return true;
  }

  void dispose() {
    _changes.close();
  }

  void _emit(EudSourceState nextState) {
    _state = nextState;
    _changes.add(nextState);
  }
}
