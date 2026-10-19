import 'dart:async';
import '../eud/eud_build_controller.dart';
import '../eud/eud_project_workspace.dart';
import '../eud/eud_source_controller.dart';
import '../ports/map_file_picker.dart';
import '../ports/map_save_file_gateway.dart';
import 'autosave_controller.dart';
import 'document_path_lease.dart';
import 'open_map_controller.dart';
import 'save_map_controller.dart';

enum WorkspacePathPurpose {
  mapOutput,
  buildOutput,
  projectOutput,
  sourceOutput,
  restoreInput,
}

/// [value] is an opaque, document-owned presentation/controller bundle.
/// Workspace rules depend only on the application controllers below.
final class WorkspaceDocument<T> {
  WorkspaceDocument({
    required this.id,
    required this.value,
    required this.maps,
    required this.saves,
    required this.sources,
    required this.builds,
    this.projects,
    this.autosave,
    required this.disposeOwned,
    this.additionalBusy,
    this.additionalChanges,
  });
  final String id;
  final T value;
  final OpenMapController maps;
  final SaveMapController saves;
  final EudSourceController sources;
  final EudBuildController builds;
  final EudProjectWorkspace? projects;
  final AutosaveController? autosave;
  final Future<void> Function() disposeOwned;
  final bool Function()? additionalBusy;
  final Stream<Object?>? additionalChanges;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  int _revision = 0;
  int get revision => _revision;
  bool get dirty =>
      (autosave?.hasTriggerDraft ?? false) ||
      (maps.state.session?.isDirty ?? false) ||
      sources.hasUnsaved ||
      (projects?.projects.isDirty ?? false);
  bool get busy {
    final progress = maps.operationProgressController.current;
    return maps.isOpening ||
        saves.isSaving ||
        maps.editHistory.isTransactionActive ||
        builds.state.isActive ||
        sources.workspaceBusy ||
        (projects?.isBusy ?? false) ||
        (autosave?.busy ?? false) ||
        (additionalBusy?.call() ?? false) ||
        (progress != null && !progress.isTerminal);
  }

  Iterable<(WorkspacePathPurpose?, String)> get inputs sync* {
    final map = maps.state.session?.sourcePath;
    if (map != null) yield (null, map);
    for (final source in sources.inputPaths) {
      yield (WorkspacePathPurpose.sourceOutput, source);
    }
    final project = projects?.projects.path;
    if (project != null) yield (WorkspacePathPurpose.projectOutput, project);
    if (builds.state.isActive) {
      final config = builds.state.plan!.configuration;
      yield (null, config.baseMapPath);
      if (config.entrySourcePath.isNotEmpty) {
        yield (null, config.entrySourcePath);
      }
    }
  }
}

final class DocumentWorkspaceController<T> {
  DocumentWorkspaceController({
    required this.createDocument,
    required this.filePicker,
    required this.paths,
    this.maximumDocuments = 8,
  });
  final WorkspaceDocument<T> Function(String id) createDocument;
  final MapFilePicker filePicker;
  final MapSaveFileGateway paths;
  final int maximumDocuments;
  final _owned = <String, WorkspaceDocument<T>>{};
  final _documents = <WorkspaceDocument<T>>[];
  final _reservations = <_PathReservation>[];
  final _changes = StreamController<void>.broadcast(sync: true);
  final _retiring = <Future<void>>{};
  Future<void>? _disposal;
  Future<void> _pathGate = Future.value();
  String? _activeId;
  int _sequence = 0, _focusRevision = 0, _pathRevision = 0;
  bool _opening = false, _disposed = false;
  Stream<void> get changes => _changes.stream;
  List<WorkspaceDocument<T>> get documents => List.unmodifiable(_documents);
  WorkspaceDocument<T>? get active => _owned[_activeId];
  bool get busy =>
      _opening ||
      _owned.length != _documents.length ||
      _owned.values.any((d) => d.busy);
  bool contains(WorkspaceDocument<T> document) =>
      identical(_owned[document.id], document);

  WorkspaceDocument<T> prepareDocument() {
    if (_disposed || _owned.length >= maximumDocuments) {
      throw StateError('WORKSPACE_DOCUMENT_LIMIT');
    }
    final id = 'map-${++_sequence}';
    final d = createDocument(id);
    if (d.id != id ||
        _owned.values.any(
          (v) =>
              identical(v.maps, d.maps) ||
              identical(v.saves, d.saves) ||
              identical(
                v.maps.operationProgressController,
                d.maps.operationProgressController,
              ) ||
              (d.projects != null && identical(v.projects, d.projects)) ||
              (d.autosave != null && identical(v.autosave, d.autosave)) ||
              identical(v.builds, d.builds) ||
              identical(v.sources, d.sources),
        )) {
      throw StateError('WORKSPACE_DOCUMENT_NOT_ISOLATED');
    }
    _owned[id] = d;
    _pathRevision++;
    void changed([Object? _]) {
      d._revision++;
      _pathRevision++;
      _notify();
    }

    d._subscriptions.addAll([
      d.maps.changes.listen(changed),
      d.saves.changes.listen(changed),
      d.sources.changes.listen(changed),
      d.builds.changes.listen(changed),
      d.maps.operationProgressController.changes.listen(changed),
      if (d.projects != null) d.projects!.changes.listen(changed),
      if (d.autosave != null) d.autosave!.changes.listen((_) => _notify()),
      if (d.additionalChanges != null) d.additionalChanges!.listen(changed),
    ]);
    return d;
  }

  void publish(WorkspaceDocument<T> d, {bool activate = true}) {
    if (activate && (active?.maps.editHistory.isTransactionActive ?? false)) {
      throw StateError('WORKSPACE_DOCUMENT_BUSY');
    }
    if (!contains(d) || _documents.contains(d)) {
      throw StateError('WORKSPACE_DOCUMENT_STALE');
    }
    _documents.add(d);
    if (activate) _activeId = d.id;
    _notify();
  }

  WorkspaceDocument<T> addEmpty() {
    final d = prepareDocument();
    publish(d);
    return d;
  }

  void activate(String id) {
    if (!_documents.any((d) => d.id == id)) {
      throw StateError('WORKSPACE_DOCUMENT_STALE');
    }
    if (active?.maps.editHistory.isTransactionActive ?? false) {
      throw StateError('WORKSPACE_DOCUMENT_BUSY');
    }
    _activeId = id;
    _focusRevision++;
    _notify();
  }

  Future<WorkspaceDocument<T>?> open({String? path}) async {
    if (_opening || _disposed) throw StateError('WORKSPACE_DOCUMENT_BUSY');
    _opening = true;
    _notify();
    WorkspaceDocument<T>? pending;
    DocumentPathLease? lease;
    final focus = _focusRevision;
    try {
      final selected = path ?? await filePicker.pickMapPath();
      if (selected == null) return null;
      for (final d in _documents) {
        final existing = d.maps.state.session?.sourcePath;
        if (existing != null &&
            await paths.refersToSameLocation(existing, selected)) {
          activate(d.id);
          return d;
        }
      }
      pending = prepareDocument();
      lease = await reserve(
        pending.id,
        selected,
        purpose: WorkspacePathPurpose.restoreInput,
      );
      final result = await pending.maps.open(sourcePath: selected);
      if (result.status != OpenMapStatus.opened || result.session == null) {
        throw StateError(
          'WORKSPACE_OPEN_FAILED: ${result.diagnostics.map((d) => d.code).join(', ')}',
        );
      }
      await lease.validate();
      publish(
        pending,
        activate:
            focus == _focusRevision &&
            !(active?.maps.editHistory.isTransactionActive ?? false),
      );
      final published = pending;
      pending = null;
      return published;
    } finally {
      lease?.release();
      if (pending != null) await abandon(pending);
      _opening = false;
      _notify();
    }
  }

  bool canAccessCheckpoint(String owner, String checkpoint) =>
      !_owned.values.any(
        (d) =>
            d.id != owner && (d.autosave?.ownsCheckpoint(checkpoint) ?? false),
      );

  Future<R> _locked<R>(Future<R> Function() action) {
    final before = _pathGate, done = Completer<void>();
    _pathGate = done.future;
    return before.then((_) => action()).whenComplete(done.complete);
  }

  Future<void> _check(
    String owner,
    String path,
    WorkspacePathPurpose purpose, {
    bool acquiring = false,
  }) async {
    final revision = _pathRevision;
    if (_disposed || !_owned.containsKey(owner)) {
      throw StateError('WORKSPACE_DOCUMENT_STALE');
    }
    for (final d in _owned.values.toList()) {
      for (final (kind, input) in d.inputs.toList()) {
        if (d.id == owner &&
            (purpose == WorkspacePathPurpose.restoreInput ||
                (purpose == WorkspacePathPurpose.projectOutput &&
                    kind == purpose) ||
                (purpose == WorkspacePathPurpose.sourceOutput &&
                    kind == purpose))) {
          continue;
        }
        if (await paths.refersToSameLocation(input, path)) {
          throw StateError('WORKSPACE_PATH_CONFLICT');
        }
      }
    }
    for (final r in _reservations.toList()) {
      if ((acquiring || r.owner != owner) &&
          await paths.refersToSameLocation(r.path, path)) {
        throw StateError('WORKSPACE_PATH_RESERVED');
      }
    }
    if (revision != _pathRevision) {
      throw StateError('WORKSPACE_DOCUMENT_CHANGED');
    }
    if (_disposed || !_owned.containsKey(owner)) {
      throw StateError('WORKSPACE_DOCUMENT_STALE');
    }
  }

  Future<DocumentPathLease> reserve(
    String owner,
    String path, {
    required WorkspacePathPurpose purpose,
  }) => _locked(() async {
    await _check(owner, path, purpose, acquiring: true);
    final reservation = _PathReservation(owner, path);
    _reservations.add(reservation);
    return DocumentPathLease(
      validate: () => validatePath(owner, path, purpose: purpose),
      release: () {
        _reservations.remove(reservation);
        _notify();
      },
    );
  });
  Future<void> validatePath(
    String owner,
    String path, {
    required WorkspacePathPurpose purpose,
  }) => _locked(() => _check(owner, path, purpose));

  Future<bool> close(
    WorkspaceDocument<T> d, {
    required int expectedRevision,
    bool discardChanges = false,
  }) async {
    if (!contains(d) ||
        d.revision != expectedRevision ||
        d.busy ||
        _reservations.any((r) => r.owner == d.id)) {
      return false;
    }
    if (d.dirty && !discardChanges) return false;
    await abandon(d);
    return true;
  }

  Future<void> abandon(WorkspaceDocument<T> d) {
    if (!contains(d)) return Future.value();
    _documents.remove(d);
    _owned.remove(d.id);
    _pathRevision++;
    if (_activeId == d.id) _activeId = _documents.lastOrNull?.id;
    _notify();
    final release = _release(d);
    _retiring.add(release);
    return release.whenComplete(() => _retiring.remove(release));
  }

  Future<void> _release(WorkspaceDocument<T> d) async {
    for (final subscription in d._subscriptions) {
      await subscription.cancel();
    }
    await d.disposeOwned();
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    for (final d in _owned.values.toList()) {
      await abandon(d);
    }
    await Future.wait(_retiring.toList());
    await _changes.close();
  }
}

final class _PathReservation {
  const _PathReservation(this.owner, this.path);
  final String owner, path;
}
