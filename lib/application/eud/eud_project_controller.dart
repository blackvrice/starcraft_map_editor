import 'dart:async';

import '../../domain/eud/eud_project.dart';
import '../ports/eud_project_store.dart';

final class EudProjectController {
  EudProjectController(this._store);
  final EudProjectStore _store;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _undo = <EudProject>[];
  final _redo = <EudProject>[];
  EudProject? _project;
  String? _savedContent;
  String? _path;
  bool _busy = false;
  bool _disposed = false;

  EudProject? get project => _project;
  String? get path => _path;
  bool get isBusy => _busy;
  bool get isDirty => _project != null && _project!.encode() != _savedContent;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  Stream<void> get changes => _changes.stream;

  bool create(EudProject project, {bool discardChanges = false}) {
    _requireAlive();
    if (_busy || (isDirty && !discardChanges)) return false;
    _reset(project, null, null);
    return true;
  }

  Future<bool> open(String path, {bool discardChanges = false}) async {
    _requireAlive();
    if (_busy || (isDirty && !discardChanges)) return false;
    _busy = true;
    _notify();
    try {
      final loaded = await _store.read(path);
      if (_disposed) return false;
      _reset(loaded, path, loaded.encode());
      return true;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// A batch becomes one undo step. Invalid batches leave the session unchanged.
  void replaceOverrides(Iterable<EudOverride> values) {
    _requireAlive();
    if (_busy) throw StateError('Project I/O is in progress.');
    final current = _project;
    if (current == null) throw StateError('No EUD project is open.');
    final next = current.withOverrides(values);
    if (next.validationIssues.isNotEmpty) {
      throw FormatException(next.validationIssues.join(', '));
    }
    if (next.encode() == current.encode()) return;
    _undo.add(current);
    _redo.clear();
    _project = next;
    _notify();
  }

  bool undo() => _move(_undo, _redo);
  bool redo() => _move(_redo, _undo);

  /// Explicit rebinding only; no path is changed as a side effect of Save As.
  void rebindMap({required String mapPath, required String mapSha256}) {
    _requireAlive();
    if (_busy || _project == null) {
      throw StateError('Project cannot be rebound now.');
    }
    final next = EudProject(
      mapPath: mapPath,
      mapSha256: mapSha256,
      overrides: _project!.overrides,
    );
    if (next.encode() == _project!.encode()) return;
    _undo.add(_project!);
    _redo.clear();
    _project = next;
    _notify();
  }

  bool _move(List<EudProject> from, List<EudProject> to) {
    _requireAlive();
    if (_busy || from.isEmpty) return false;
    to.add(_project!);
    _project = from.removeLast();
    _notify();
    return true;
  }

  Future<void> saveAs(String path) async {
    _requireAlive();
    final snapshot = _project;
    if (_busy || snapshot == null) {
      throw StateError('Project cannot be saved now.');
    }
    _busy = true;
    _notify();
    try {
      await _store.saveAs(path, snapshot);
      if (!_disposed) {
        _savedContent = snapshot.encode();
        _path = path;
      }
    } finally {
      _busy = false;
      _notify();
    }
  }

  bool close({bool discardChanges = false}) {
    _requireAlive();
    if (_busy || (isDirty && !discardChanges)) return false;
    _reset(null, null, null);
    return true;
  }

  void _reset(EudProject? project, String? path, String? saved) {
    _project = project;
    _path = path;
    _savedContent = saved;
    _undo.clear();
    _redo.clear();
    _notify();
  }

  void _requireAlive() {
    if (_disposed) throw StateError('EUD project controller is disposed.');
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  void dispose() {
    _disposed = true;
    _changes.close();
  }
}
