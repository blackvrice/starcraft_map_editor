import 'dart:async';

import 'opened_map_session.dart';

/// One chronological history for all edits of the active map document.
/// Commands retain immutable section/resource identities, not encoded copies.
class MapEditHistory {
  MapEditHistory({required this.currentSession});

  final OpenedMapSession? Function() currentSession;
  final _changes = StreamController<void>.broadcast(sync: true);
  final List<_MapEdit> _undo = [];
  final List<_MapEdit> _redo = [];
  Object? _source;
  Object? _transactionOwner;
  int _limit = 100;

  Stream<void> get changes => _changes.stream;
  int get undoDepth => _undo.length;
  int get redoDepth => _redo.length;
  bool get isTransactionActive => _transactionOwner != null;
  bool get canUndo => _transactionOwner == null && _undo.isNotEmpty;
  bool get canRedo => _transactionOwner == null && _redo.isNotEmpty;
  String? get undoLabel => canUndo ? _undo.last.label : null;
  String? get redoLabel => canRedo ? _redo.last.label : null;

  void constrainLimit(int limit) {
    if (limit < _limit) {
      _limit = limit;
    }
  }

  void synchronizeSession(OpenedMapSession? session) {
    if (identical(_source, session?.extractedMap)) {
      return;
    }
    _source = session?.extractedMap;
    _undo.clear();
    _redo.clear();
    _transactionOwner = null;
    _changes.add(null);
  }

  void ensureCanEdit(Object owner) {
    if (_transactionOwner != null && !identical(_transactionOwner, owner)) {
      throw StateError('Finish the active brush stroke before another edit.');
    }
  }

  void beginTransaction(Object owner) {
    ensureCanEdit(owner);
    _transactionOwner = owner;
    _changes.add(null);
  }

  void endTransaction(Object owner) {
    ensureCanEdit(owner);
    _transactionOwner = null;
    _changes.add(null);
  }

  void record({
    required String label,
    required OpenedMapSession before,
    required OpenedMapSession after,
    required void Function() undo,
    required void Function() redo,
  }) {
    final actual = currentSession();
    if (actual == null ||
        !identical(before.extractedMap, after.extractedMap) ||
        !identical(_source, after.extractedMap) ||
        !_matches(actual, after)) {
      throw StateError('Cannot record an edit for a stale map document.');
    }
    _undo.add(_MapEdit(label, before, after, undo, redo));
    if (_undo.length > _limit) {
      _undo.removeAt(0);
    }
    _redo.clear();
    _changes.add(null);
  }

  bool undo() => _move(_undo, _redo, backwards: true);
  bool redo() => _move(_redo, _undo, backwards: false);

  bool _move(
    List<_MapEdit> from,
    List<_MapEdit> to, {
    required bool backwards,
  }) {
    if (_transactionOwner != null || from.isEmpty) {
      return false;
    }
    final command = from.last;
    final expected = backwards ? command.after : command.before;
    final actual = currentSession();
    if (actual == null || !_matches(actual, expected)) {
      throw StateError(
        'Map edit history no longer matches the active document.',
      );
    }
    // Do not consume the command if validation or application fails.
    (backwards ? command.undo : command.redo)();
    from.removeLast();
    to.add(command);
    _changes.add(null);
    return true;
  }

  bool _matches(OpenedMapSession actual, OpenedMapSession expected) {
    final a = actual.rawDocument.sections;
    final b = expected.rawDocument.sections;
    if (!identical(actual.extractedMap, expected.extractedMap) ||
        actual.sourceFingerprint != expected.sourceFingerprint ||
        !identical(actual.resourceEdits, expected.resourceEdits) ||
        a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  Future<void> dispose() => _changes.close();
}

class _MapEdit {
  const _MapEdit(this.label, this.before, this.after, this.undo, this.redo);
  final String label;
  final OpenedMapSession before, after;
  final void Function() undo, redo;
}
