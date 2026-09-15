import 'dart:async';
import '../../domain/eud/eud_project.dart';
import '../documents/open_map_controller.dart';
import '../documents/opened_map_session.dart';
import '../ports/eud_project_picker.dart';
import 'eud_project_controller.dart';

enum EudMapBinding {
  unchecked,
  noMap,
  unsavedMap,
  restrictedMap,
  matched,
  mismatch,
  diskChanged,
}

/// Verifies only the map explicitly opened in the editor. Never opens a path
/// supplied by a project file, nor starts a compiler.
final class EudProjectWorkspace {
  EudProjectWorkspace({
    required this.projects,
    required this.maps,
    required this.picker,
  }) {
    _mapSubscription = maps.changes.listen((_) {
      _generation++;
      _binding = EudMapBinding.unchecked;
      _notify();
    });
    _projectSubscription = projects.changes.listen((_) {
      _generation++;
      _binding = EudMapBinding.unchecked;
      _notify();
    });
  }
  final EudProjectController projects;
  final OpenMapController maps;
  final EudProjectPicker picker;
  late final StreamSubscription<OpenMapState> _mapSubscription;
  late final StreamSubscription<void> _projectSubscription;
  final _changes = StreamController<void>.broadcast(sync: true);
  int _generation = 0;
  bool _disposed = false;
  bool _busy = false;
  EudMapBinding _binding = EudMapBinding.unchecked;
  Stream<void> get changes => _changes.stream;
  bool get isBusy => _busy || projects.isBusy;
  bool get hasUnbuiltOverrides =>
      projects.project?.overrides.isNotEmpty ?? false;
  EudMapBinding get binding {
    final session = maps.state.session;
    if (session == null) return EudMapBinding.noMap;
    if (session.isDirty) return EudMapBinding.unsavedMap;
    if (session.requiresRestrictedEditing) return EudMapBinding.restrictedMap;
    return _binding;
  }

  Future<void> createFromMap({bool discardChanges = false}) => _run(() async {
    final session = await _verifiedMap();
    if (!projects.create(
      EudProject(
        mapPath: session.sourcePath,
        mapSha256: session.sourceFingerprint.sha256Digest,
      ),
      discardChanges: discardChanges,
    )) {
      throw StateError('Save or discard the current EUD project first.');
    }
    _binding = EudMapBinding.matched;
  });

  Future<void> rebind() => _run(() async {
    final session = await _verifiedMap();
    projects.rebindMap(
      mapPath: session.sourcePath,
      mapSha256: session.sourceFingerprint.sha256Digest,
    );
    _binding = EudMapBinding.matched;
  });

  Future<void> verify() => _run(() async {
    final session = await _verifiedMap();
    final project = projects.project;
    _binding =
        project != null &&
            _normalize(project.mapPath) == _normalize(session.sourcePath) &&
            project.mapSha256 == session.sourceFingerprint.sha256Digest
        ? EudMapBinding.matched
        : EudMapBinding.mismatch;
  });

  Future<void> open({bool discardChanges = false}) => _run(() async {
    final path = await picker.openProject();
    if (_disposed || path == null) return;
    if (!await projects.open(path, discardChanges: discardChanges)) {
      throw StateError('Save or discard the current EUD project first.');
    }
  });

  Future<void> saveAs() => _run(() async {
    final path = await picker.saveProjectAs();
    if (_disposed || path == null) return;
    await projects.saveAs(path);
  });

  Future<void> save() => _run(projects.save);

  Future<OpenedMapSession> _verifiedMap() async {
    _binding = EudMapBinding.unchecked;
    final session = maps.state.session;
    final progress = maps.operationProgressController.current;
    if (session == null || (progress != null && !progress.isTerminal)) {
      throw StateError('Open a map first.');
    }
    if (session.isDirty || session.requiresRestrictedEditing) {
      throw StateError(
        'Save the editable map before connecting an EUD project.',
      );
    }
    final generation = _generation;
    final current = await maps.fingerprintGateway.fingerprint(
      session.sourcePath,
    );
    if (_disposed ||
        generation != _generation ||
        !identical(session, maps.state.session)) {
      throw StateError(
        'The map or project changed during verification. Try again.',
      );
    }
    if (current != session.sourceFingerprint) {
      _binding = EudMapBinding.diskChanged;
      throw StateError('The map changed on disk. Reopen it before continuing.');
    }
    return session;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_disposed || isBusy) {
      throw StateError('EUD project operation unavailable.');
    }
    _busy = true;
    _notify();
    try {
      await action();
    } finally {
      _busy = false;
      _notify();
    }
  }

  static String _normalize(String value) =>
      value.replaceAll('\\', '/').toLowerCase();
  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  void dispose() {
    _disposed = true;
    _mapSubscription.cancel();
    _projectSubscription.cancel();
    _changes.close();
  }
}
