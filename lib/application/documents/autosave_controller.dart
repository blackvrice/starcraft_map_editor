import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import '../../domain/chk/typed/chk_player_settings_editor.dart';
import '../eud/eud_project_controller.dart';
import '../eud/eud_source_controller.dart';
import '../ports/map_archive_gateway.dart';
import '../ports/recovery_store.dart';
import '../ports/settings_store.dart';
import 'open_map_controller.dart';
import 'opened_map_session.dart';
import 'recovery_snapshot.dart';

final class RecoveryCandidate {
  const RecoveryCandidate(this.id, this.snapshot);
  final String id;
  final RecoverySnapshot? snapshot;
}

final class AutosaveController {
  AutosaveController({
    required this.maps,
    required this.sources,
    required this.projects,
    required this.store,
    required this.settings,
    String? ownerId,
    DateTime Function()? clock,
  }) : _ownerId =
           ownerId ??
           '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
       _clock = clock ?? DateTime.now {
    _mapIdentity = maps.state.session?.extractedMap;
    _projectIdentity = projects.path;
    _sourceIdentity = sources.state.document?.documentId;
    _subscriptions.add(maps.changes.listen((_) => _changed()));
    _subscriptions.add(sources.changes.listen((_) => _changed()));
    _subscriptions.add(projects.changes.listen((_) => _changed()));
  }

  final OpenMapController maps;
  final EudSourceController sources;
  final EudProjectController projects;
  final RecoveryStore store;
  final SettingsStore settings;
  final String _ownerId;
  final DateTime Function() _clock;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<String> _owned = [];
  Timer? _timer;
  Future<void>? _pending;
  bool _disposed = false;
  bool _restoring = false;
  int _revision = 1;
  int _writtenRevision = 0;
  int _sequence = 0;
  Object? _mapIdentity;
  String? _projectIdentity;
  String? _sourceIdentity;
  Duration interval = const Duration(seconds: 30);
  int retention = 5;
  bool enabled = true;
  DateTime? lastSavedAt;
  String? lastError;
  List<RecoveryCandidate> candidates = const [];
  Stream<void> get changes => _changes.stream;
  bool get busy => _restoring || _pending != null;

  void _changed() {
    final map = maps.state.session?.extractedMap;
    final project = projects.path;
    final source = sources.state.document?.documentId;
    if (!identical(map, _mapIdentity) ||
        project != _projectIdentity ||
        source != _sourceIdentity) {
      // A replaced document's backup remains available until explicitly removed.
      if (_hasUnsaved) _owned = [];
      _mapIdentity = map;
      _projectIdentity = project;
      _sourceIdentity = source;
    }
    _revision++;
  }

  Future<void> initialize() async {
    String? settingsError;
    try {
      final value = await settings.readString('autosaveIntervalSeconds');
      final seconds = int.tryParse(value ?? '') ?? 30;
      interval = Duration(seconds: seconds.clamp(5, 600));
      retention =
          (int.tryParse(await settings.readString('autosaveRetention') ?? '') ??
                  5)
              .clamp(1, 20);
      enabled = await settings.readString('autosaveEnabled') != 'false';
    } on Object {
      settingsError = 'AUTOSAVE_SETTINGS_FAILED';
    }
    await refresh();
    lastError ??= settingsError;
    if (!_disposed) _restartTimer();
    _notify();
  }

  Future<void> configure({
    required bool enabled,
    required Duration interval,
    required int retention,
  }) async {
    if (interval.inSeconds < 5 ||
        interval.inSeconds > 600 ||
        retention < 1 ||
        retention > 20) {
      throw ArgumentError('Invalid autosave settings.');
    }
    await settings.writeString('autosaveEnabled', enabled.toString());
    await settings.writeString(
      'autosaveIntervalSeconds',
      interval.inSeconds.toString(),
    );
    await settings.writeString('autosaveRetention', retention.toString());
    this.enabled = enabled;
    this.interval = interval;
    this.retention = retention;
    _restartTimer();
    _notify();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (enabled && !_disposed) {
      _timer = Timer.periodic(interval, (_) => unawaited(checkpoint()));
    }
  }

  bool get _hasUnsaved =>
      (maps.state.session?.isDirty ?? false) ||
      projects.isDirty ||
      (sources.state.document?.isDirty ?? false) ||
      (sources.state.document?.isUntitled ?? false);

  Future<void> checkpoint() {
    if (_disposed || _restoring) return Future.value();
    if (_pending != null) return _pending!;
    final task = _checkpoint();
    _pending = task;
    return task.whenComplete(() {
      _pending = null;
      _notify();
    });
  }

  Future<void> _checkpoint() async {
    final progress = maps.operationProgressController.current;
    if (maps.editHistory.isTransactionActive ||
        projects.isBusy ||
        (progress != null && !progress.isTerminal) ||
        _revision == _writtenRevision) {
      return;
    }
    final revision = _revision;
    final owned = _owned;
    try {
      if (!_hasUnsaved) {
        for (final id in owned.toList()) {
          await store.remove(id);
          owned.remove(id);
        }
        _writtenRevision = revision;
        lastError = null;
        return;
      }
      final session = maps.state.session;
      if (session?.requiresRestrictedEditing ?? false) {
        throw StateError('Restricted map cannot be checkpointed.');
      }
      final snapshot = RecoverySnapshot(
        savedAt: _clock().toUtc(),
        map: session == null ? null : RecoveryMap.capture(session),
        project: projects.project,
        projectPath: projects.path,
        source: sources.state.document,
      );
      final id = 'checkpoint-$_ownerId-${++_sequence}';
      final content = await Isolate.run(snapshot.encode);
      await store.write(id, content);
      // Do not prune a different document after asynchronous I/O.
      owned.add(id);
      if (identical(owned, _owned)) {
        while (owned.length > retention) {
          await store.remove(owned.first);
          owned.removeAt(0);
        }
        _writtenRevision = revision;
      }
      lastSavedAt = snapshot.savedAt;
      lastError = null;
    } on Object {
      lastError = 'AUTOSAVE_WRITE_FAILED';
    }
  }

  Future<void> refresh() async {
    try {
      final entries = await store.list();
      candidates = await Isolate.run(
        () => List<RecoveryCandidate>.unmodifiable(
          entries.map((entry) {
            try {
              return RecoveryCandidate(
                entry.id,
                RecoverySnapshot.decode(entry.content),
              );
            } on Object {
              return RecoveryCandidate(entry.id, null);
            }
          }).toList()..sort(
            (a, b) => (b.snapshot?.savedAt ?? DateTime(1970)).compareTo(
              a.snapshot?.savedAt ?? DateTime(1970),
            ),
          ),
        ),
      );
      lastError = null;
    } on Object {
      lastError = 'AUTOSAVE_READ_FAILED';
    }
    _notify();
  }

  Future<void> remove(String id) async {
    if (busy) throw StateError('Recovery is busy.');
    await store.remove(id);
    _owned.remove(id);
    await refresh();
  }

  Future<void> restore(String id) async {
    if (busy ||
        _hasUnsaved ||
        maps.editHistory.isTransactionActive ||
        projects.isBusy) {
      throw StateError('RECOVERY_DOCUMENT_BUSY');
    }
    final progress = maps.operationProgressController;
    if (progress.current != null && !progress.current!.isTerminal) {
      throw StateError('RECOVERY_DOCUMENT_BUSY');
    }
    final oldMap = maps.state.session;
    final oldSource = sources.state.document;
    final oldProject = projects.project;
    _restoring = true;
    final operationId = 'restore-$_ownerId-${++_sequence}';
    progress.start(
      operationId: operationId,
      label: 'Recovery',
      canCancel: false,
    );
    _notify();
    try {
      final entry = (await store.list()).singleWhere((entry) => entry.id == id);
      final content = entry.content;
      final snapshot = await Isolate.run(
        () => RecoverySnapshot.decode(content),
      );
      OpenedMapSession? session;
      final map = snapshot.map;
      if (map != null) {
        ExtractedMap extracted;
        if (map.sourcePath == null) {
          extracted = ExtractedMap.inMemory(scenarioChkBytes: map.baseline);
        } else {
          final before = await maps.fingerprintGateway.fingerprint(
            map.sourcePath!,
          );
          if (before != map.fingerprint) {
            throw StateError('RECOVERY_SOURCE_CHANGED');
          }
          final result = await maps.archiveGateway.open(
            MapArchiveOpenRequest(
              operationId: operationId,
              sourcePath: map.sourcePath!,
              timeout: maps.archiveTimeout,
            ),
          );
          if (!result.isSuccess) throw StateError('RECOVERY_SOURCE_UNREADABLE');
          final after = await maps.fingerprintGateway.fingerprint(
            map.sourcePath!,
          );
          if (before != after || after != map.fingerprint) {
            throw StateError('RECOVERY_SOURCE_CHANGED');
          }
          extracted = result.extractedMap!;
          if (!_sameBytes(extracted.scenarioChkBytes, map.baseline)) {
            throw StateError('RECOVERY_BASELINE_MISMATCH');
          }
        }
        final doc = map.document;
        final metadata = maps.metadataViewDecoder.decode(doc);
        final strings = maps.stringViewDecoder.decode(doc);
        final terrain = maps.terrainViewDecoder.decode(doc);
        final objects = maps.objectViewDecoder.decode(doc);
        session = OpenedMapSession(
          extractedMap: extracted,
          rawDocument: doc,
          metadataViews: metadata,
          stringViews: strings,
          terrainViews: terrain,
          objectViews: objects,
          sourceFingerprint: map.fingerprint,
          resourceEdits: map.resources,
          diagnostics: [
            ...metadata.diagnostics,
            ...strings.diagnostics,
            ...terrain.diagnostics,
            ...objects.diagnostics,
            ...maps.objectReferenceValidator.validate(
              metadataViews: metadata,
              stringViews: strings,
              objectViews: objects,
            ),
            ...const ChkPlayerSettingsEditor().diagnostics(doc),
          ],
        );
        if (session.requiresRestrictedEditing) {
          throw StateError('RECOVERY_INVALID_DOCUMENT');
        }
      }
      if (_disposed ||
          !identical(oldMap, maps.state.session) ||
          !identical(oldSource, sources.state.document) ||
          !identical(oldProject, projects.project) ||
          projects.isBusy ||
          _hasUnsaved) {
        throw StateError('RECOVERY_DOCUMENT_CHANGED');
      }
      // Everything is validated before any controller is changed. No compiler runs.
      if (session != null) maps.adoptRecoverySession(session);
      if (snapshot.project != null) projects.create(snapshot.project!);
      if (snapshot.source != null) sources.restore(snapshot.source!);
      _owned.add(id);
      _revision++;
      progress.succeed(operationId: operationId, message: 'Recovery opened');
      lastError = null;
    } on Object catch (error) {
      lastError =
          error is StateError && error.message == 'RECOVERY_SOURCE_CHANGED'
          ? 'RECOVERY_SOURCE_CHANGED'
          : 'RECOVERY_FAILED';
      progress.fail(operationId: operationId, message: lastError!);
      rethrow;
    } finally {
      _restoring = false;
      _notify();
    }
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _pending;
    await _changes.close();
  }
}
