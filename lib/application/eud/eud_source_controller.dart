import 'dart:async';
import 'dart:isolate';
import '../../domain/eud/portable_eud_script.dart';

import 'eud_source_document.dart';
import '../ports/trigger_script_gateway.dart';
import '../../domain/triggers/trigger_script_syntax.dart';
import '../ports/eud_source_translation_gateway.dart';
import '../ports/source_workspace_gateway.dart';
import '../documents/document_path_lease.dart';
import '../../domain/eud/source_workspace_index.dart';
import 'source_workspace_recovery.dart';

final class EudSourceState {
  const EudSourceState({required this.document});

  const EudSourceState.closed() : document = null;

  final EudSourceDocument? document;

  bool get hasDocument => document != null;
}

final class EudSourceController {
  EudSourceController({
    this.files,
    this.translator,
    this.workspaceGateway,
    this.reserveWrite,
  }) : _state = const EudSourceState.closed();
  final TriggerScriptFiles? files;
  final SourceWorkspaceGateway? workspaceGateway;
  final DocumentPathReserver? reserveWrite;
  final _documents = <String, EudSourceDocument>{};
  List<EudSourceDocument> get documents => List.unmodifiable(_documents.values);
  bool get hasUnsaved => documents.any((d) => d.isDirty || d.isUntitled);
  int revision = 0, workspaceEpoch = 0;
  String? root;
  bool workspaceVerified = false, workspaceBusy = false, indexPending = false;
  String? workspaceError;
  SourceWorkspaceIndex? index;
  final _disk = <String, SourceWorkspaceFile>{};
  final conflicts = <String>{};
  List<SourceWorkspaceFile> get workspaceFiles =>
      List.unmodifiable(_disk.values);
  Timer? _indexTimer;
  int _indexRequest = 0;
  ({String id, int offset, int sequence})? focusRequest;
  int _focusSequence = 0;
  SourceWorkspaceRecovery? get recovery => documents.isEmpty
      ? null
      : SourceWorkspaceRecovery(
          root: root,
          activeId: _state.document!.documentId,
          documents: documents,
        );
  Iterable<String> get inputPaths sync* {
    final paths = <String>{};
    for (final path in [
      ...documents.map((d) => d.sourcePath).whereType<String>(),
      ..._disk.values.map((f) => f.path),
    ]) {
      if (paths.add(SourcePaths.key(path))) yield path;
    }
  }

  String? relativeFor(String? path) {
    if (path == null || root == null) return null;
    final p = SourcePaths.key(path), base = SourcePaths.key(root!);
    if (!p.startsWith('$base/')) return null;
    final relative = path.replaceAll('\\', '/').substring(base.length + 1);
    try {
      return SourcePaths.relative(relative);
    } on FormatException {
      return null;
    }
  }

  Future<bool> chooseWorkspace() async {
    if (workspaceGateway == null || workspaceBusy) return false;
    final chosen = await workspaceGateway!.chooseRoot();
    if (chosen == null || _disposed) return false;
    return openWorkspace(chosen);
  }

  Future<bool> openWorkspace(String path) async {
    if (workspaceGateway == null || workspaceBusy) return false;
    if (root != null &&
        SourcePaths.key(root!) != SourcePaths.key(path) &&
        documents.any((d) => !d.isUntitled || d.text.isNotEmpty)) {
      throw StateError('SOURCE_CLOSE_TABS_BEFORE_ROOT_CHANGE');
    }
    return _workspaceTask(() async {
      final scan = await workspaceGateway!.scan(path);
      if (_disposed) return false;
      final next = {for (final f in scan.files) f.relativePath: f};
      // Opening another root must never hide a loaded source outside it.
      final prefix = '${SourcePaths.key(scan.root)}/';
      if (documents.any(
        (d) =>
            d.sourcePath != null &&
            !SourcePaths.key(d.sourcePath!).startsWith(prefix),
      )) {
        throw StateError('SOURCE_OPEN_FILE_OUTSIDE_ROOT');
      }
      root = scan.root;
      workspaceVerified = true;
      _disk
        ..clear()
        ..addAll(next);
      workspaceEpoch++;
      _detectConflicts();
      await rebuildIndex();
      _announce();
      return true;
    });
  }

  Future<bool> refreshWorkspace() async {
    if (root == null || workspaceGateway == null || workspaceBusy) return false;
    return _workspaceTask(() async {
      workspaceVerified = false;
      final scan = await workspaceGateway!.scan(root!);
      if (_disposed) return false;
      _disk
        ..clear()
        ..addEntries(scan.files.map((f) => MapEntry(f.relativePath, f)));
      workspaceVerified = true;
      _detectConflicts();
      await rebuildIndex();
      _announce();
      return true;
    });
  }

  void _detectConflicts() {
    conflicts.clear();
    for (final d in documents) {
      final rel = relativeFor(d.sourcePath);
      if (rel == null) continue;
      final disk = _disk[rel];
      if (disk == null || disk.text != d.savedText) conflicts.add(d.documentId);
    }
  }

  Future<bool> _workspaceTask(Future<bool> Function() action) async {
    if (workspaceBusy || _disposed) return false;
    workspaceBusy = true;
    workspaceError = null;
    _announce();
    try {
      return await action();
    } on Object catch (e) {
      if (!_disposed) workspaceError = '$e';
      rethrow;
    } finally {
      if (!_disposed) {
        workspaceBusy = false;
        _announce();
      }
    }
  }

  Future<void> rebuildIndex() async {
    _indexTimer?.cancel();
    final request = ++_indexRequest;
    final text = {for (final f in _disk.values) f.relativePath: f.text};
    for (final d in documents) {
      final rel = relativeFor(d.sourcePath);
      if (rel != null) text[rel] = d.text;
    }
    indexPending = true;
    try {
      final result = await Isolate.run(() => SourceWorkspaceIndex(text));
      if (_disposed || request != _indexRequest) return;
      index = result;
      workspaceError = null;
    } on Object catch (e) {
      if (!_disposed && request == _indexRequest) {
        index = null;
        workspaceError = '$e';
      }
    } finally {
      if (!_disposed && request == _indexRequest) {
        indexPending = false;
        _announce();
      }
    }
  }

  void _scheduleIndex() {
    if (root == null) return;
    _indexTimer?.cancel();
    _indexRequest++;
    indexPending = true;
    _indexTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(rebuildIndex()),
    );
  }

  Future<bool> openRelative(String relative) async {
    SourcePaths.relative(relative);
    if (root == null || !workspaceVerified || workspaceGateway == null) {
      throw StateError('SOURCE_ROOT_UNVERIFIED');
    }
    final file = _disk[relative];
    if (file == null) throw StateError('SOURCE_NOT_INDEXED');
    final existing = documents
        .where(
          (d) =>
              d.sourcePath != null &&
              SourcePaths.key(d.sourcePath!) == SourcePaths.key(file.path),
        )
        .firstOrNull;
    if (existing != null) {
      activate(existing.documentId);
      return true;
    }
    if (documents.length >= 16) throw StateError('SOURCE_TAB_LIMIT');
    return _workspaceTask(() async {
      final read = await workspaceGateway!.read(root!, relative);
      if (_disposed) return false;
      if (read.revision != file.revision) {
        throw StateError('SOURCE_EXTERNAL_CHANGE_REFRESH');
      }
      _emit(
        EudSourceState(
          document: EudSourceDocument.opened(
            documentId: _newId('tab'),
            sourcePath: read.path,
            text: read.text,
          ),
        ),
      );
      return true;
    });
  }

  void activate(String id) {
    final d = _documents[id];
    if (d == null) throw StateError('SOURCE_TAB_MISSING');
    _emit(EudSourceState(document: d));
  }

  bool newTab({String fileName = 'main.eps', String initialText = ''}) {
    if (documents.length >= 16) throw StateError('SOURCE_TAB_LIMIT');
    _emit(
      EudSourceState(
        document: EudSourceDocument.untitled(
          documentId: _newId('tab'),
          fileName: fileName,
          initialText: initialText,
        ),
      ),
    );
    return true;
  }

  bool closeTab(String id, {bool discardChanges = false}) {
    if (workspaceBusy) return false;
    final d = _documents[id];
    if (d == null) return true;
    if ((d.isDirty || (d.isUntitled && d.text.isNotEmpty)) && !discardChanges) {
      return false;
    }
    _documents.remove(id);
    conflicts.remove(id);
    if (_state.document?.documentId == id) {
      _state = EudSourceState(document: _documents.values.lastOrNull);
    }
    _scheduleIndex();
    _announce();
    return true;
  }

  void restoreWorkspace(SourceWorkspaceRecovery recovery) {
    if (hasUnsaved || workspaceBusy) throw StateError('SOURCE_WORKSPACE_DIRTY');
    _documents
      ..clear()
      ..addEntries(recovery.documents.map((d) => MapEntry(d.documentId, d)));
    _untitledSequence += 1000;
    _indexTimer?.cancel();
    _indexRequest++;
    indexPending = false;
    root = recovery.root;
    workspaceVerified = false;
    _disk.clear();
    index = null;
    conflicts.clear();
    workspaceEpoch++;
    _state = EudSourceState(document: _documents[recovery.activeId]);
    _announce();
  }

  Future<bool> reloadActive({bool discardChanges = false}) async {
    final d = _state.document, rel = relativeFor(_state.document?.sourcePath);
    if (d == null ||
        rel == null ||
        workspaceGateway == null ||
        !workspaceVerified) {
      return false;
    }
    if (d.isDirty && !discardChanges) throw StateError('SOURCE_DIRTY');
    return _workspaceTask(() async {
      final file = await workspaceGateway!.read(root!, rel);
      if (_disposed || !identical(d, _documents[d.documentId])) return false;
      _disk[rel] = file;
      conflicts.remove(d.documentId);
      _emit(
        EudSourceState(
          document: EudSourceDocument.opened(
            documentId: d.documentId,
            sourcePath: file.path,
            text: file.text,
          ),
        ),
      );
      await rebuildIndex();
      return true;
    });
  }

  Future<bool> saveActive() async {
    final d = _state.document, rel = relativeFor(_state.document?.sourcePath);
    if (d == null ||
        rel == null ||
        workspaceGateway == null ||
        !workspaceVerified) {
      throw StateError('SOURCE_ROOT_UNVERIFIED');
    }
    if (conflicts.contains(d.documentId) || _disk[rel] == null) {
      throw StateError('SOURCE_EXTERNAL_CHANGE');
    }
    return _workspaceTask(() async {
      final lease = await reserveWrite?.call(d.sourcePath!);
      try {
        await lease?.validate();
        final saved = await workspaceGateway!.save(
          root!,
          rel,
          d.text,
          _disk[rel]!.revision,
        );
        if (_disposed) return false;
        _disk[rel] = saved;
        final latest = _documents[d.documentId];
        if (latest != null && latest.sourcePath == d.sourcePath) {
          _documents[d.documentId] = latest.withSavedText(d.text);
          if (_state.document?.documentId == d.documentId) {
            _state = EudSourceState(document: _documents[d.documentId]);
          }
        }
        _detectConflicts();
        await rebuildIndex();
        _announce();
        return true;
      } finally {
        lease?.release();
      }
    });
  }

  Future<void> validateForBuild(String sourceRoot, String entry) async {
    if (root == null) return;
    if (SourcePaths.key(sourceRoot) != SourcePaths.key(root!)) {
      throw StateError('SOURCE_BUILD_ROOT_MISMATCH');
    }
    if (!await refreshWorkspace() ||
        !workspaceVerified ||
        conflicts.isNotEmpty ||
        hasUnsaved ||
        workspaceError != null) {
      throw StateError('SOURCE_BUILD_NOT_READY');
    }
    final rel = relativeFor(entry);
    if (rel == null ||
        !_disk.containsKey(rel) ||
        rel.endsWith('.lua') ||
        (index?.issues.isNotEmpty ?? true)) {
      throw StateError('SOURCE_BUILD_NOT_READY');
    }
  }

  Future<bool> navigate(String file, int line, {int column = 1}) async {
    if (line < 1 || column < 1 || root == null || !workspaceVerified) {
      throw StateError('SOURCE_DIAGNOSTIC_POSITION');
    }
    final normalized = file.replaceAll('\\', '/');
    final candidates = _disk.values
        .where(
          (f) =>
              SourcePaths.key(f.path) == SourcePaths.key(normalized) ||
              SourcePaths.key(f.relativePath) == SourcePaths.key(normalized) ||
              (!normalized.contains('/') &&
                  (f.relativePath.split('/').last == normalized ||
                      f.relativePath
                              .split('/')
                              .last
                              .replaceFirst(RegExp(r'\.(eps|py|lua)$'), '') ==
                          normalized)),
        )
        .toList();
    if (candidates.length != 1) {
      throw StateError('SOURCE_DIAGNOSTIC_UNRESOLVED');
    }
    await openRelative(candidates.single.relativePath);
    final d = _state.document!;
    final lines = d.text.split('\n');
    if (line > lines.length ||
        column > lines[line - 1].replaceAll('\r', '').length + 1) {
      throw StateError('SOURCE_DIAGNOSTIC_POSITION');
    }
    final offset =
        lines.take(line - 1).fold<int>(0, (n, s) => n + s.length + 1) +
        column -
        1;
    focusRequest = (
      id: d.documentId,
      offset: offset,
      sequence: ++_focusSequence,
    );
    _announce();
    return true;
  }

  void updateDocumentText(String id, String text) {
    final d = _documents[id];
    if (d == null || d.text == text) return;
    _documents[id] = d.withText(text);
    if (_state.document?.documentId == id) {
      _state = EudSourceState(document: _documents[id]);
    }
    _scheduleIndex();
    _announce();
  }

  final EudSourceTranslationGateway? translator;
  EudSourceTranslation? latestTranslation;
  bool _disposed = false;

  Future<String> translate(TriggerScriptLanguage target) async {
    final current = _state.document;
    if (current == null) throw StateError('EUD_NO_SOURCE');
    latestTranslation = null;
    if (current.language == TriggerScriptLanguage.epScript &&
        target == TriggerScriptLanguage.python &&
        translator != null) {
      final result = await translator!.toPython(current.text);
      if (_disposed || !identical(current, _state.document)) {
        throw StateError('SCRIPT_SOURCE_CHANGED');
      }
      latestTranslation = result;
      return result.source;
    }
    final translated = await Isolate.run(
      () => PortableEudScript.parse(
        current.text,
        current.language,
      ).convert(target),
    );
    if (_disposed || !identical(current, _state.document)) {
      throw StateError('SCRIPT_SOURCE_CHANGED');
    }
    return translated;
  }

  Future<String?> exportTranslation(
    String text,
    TriggerScriptLanguage target,
  ) => files?.saveNew(text, target) ?? Future.value();

  Future<bool> openFile() async {
    if (workspaceBusy) return false;
    final old = _state.document;
    if (root == null &&
        ((old?.isDirty ?? false) ||
            ((old?.isUntitled ?? false) && old!.text.isNotEmpty))) {
      throw StateError('SCRIPT_DIRTY');
    }
    final file = await files?.open();
    if (file == null) return false;
    if (_disposed || !identical(old, _state.document)) {
      throw StateError('SCRIPT_SOURCE_CHANGED');
    }
    if (root != null) {
      final rel = relativeFor(file.path);
      if (rel == null) throw StateError('SOURCE_OPEN_FILE_OUTSIDE_ROOT');
      return openRelative(rel);
    }
    if (file.language == TriggerScriptLanguage.lua) {
      throw StateError('EUD_NATIVE_LUA_UNSUPPORTED');
    }
    return open(sourcePath: file.path, text: file.text);
  }

  Future<bool> saveNew() async {
    final current = _state.document;
    if (current == null || files == null || workspaceBusy) return false;
    if (root != null) {
      return _workspaceTask(() async {
        final path = await files!.saveNew(current.text, current.language);
        if (path == null || _disposed) return false;
        final rel = relativeFor(path);
        if (rel == null) throw StateError('SOURCE_SAVED_COPY_OUTSIDE_ROOT');
        if (workspaceGateway == null) {
          throw StateError('SOURCE_ROOT_UNVERIFIED');
        }
        final saved = await workspaceGateway!.read(root!, rel);
        if (_disposed) return false;
        if (saved.text != current.text) {
          throw StateError('SOURCE_EXTERNAL_CHANGE');
        }
        _disk[rel] = saved;
        if (identical(current, _state.document)) markSaved(sourcePath: path);
        _detectConflicts();
        await rebuildIndex();
        _announce();
        return true;
      });
    }
    final path = await files!.saveNew(current.text, current.language);
    if (path == null) return false;
    // A late Save As must not mark newer text as saved.
    if (!_disposed && root == null && identical(current, _state.document)) {
      markSaved(sourcePath: path);
    }
    return true;
  }

  bool changeEmptyLanguage(TriggerScriptLanguage language) {
    final current = _state.document;
    if (current == null ||
        !current.isUntitled ||
        current.text.isNotEmpty ||
        (language == TriggerScriptLanguage.lua && root == null)) {
      return false;
    }
    _emit(
      EudSourceState(
        document: EudSourceDocument.untitled(
          documentId: current.documentId,
          fileName: 'main.${language.extension}',
        ),
      ),
    );
    return true;
  }

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
    _emit(
      EudSourceState(
        document: EudSourceDocument.untitled(
          documentId: _newId('untitled'),
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
    if (root != null && relativeFor(sourcePath) == null) {
      throw StateError('SOURCE_OPEN_FILE_OUTSIDE_ROOT');
    }
    final current = _state.document;
    if (current?.isDirty ?? false) {
      if (!discardChanges) {
        return false;
      }
    }
    final document = EudSourceDocument.opened(
      documentId: _newId('source'),
      sourcePath: sourcePath,
      text: text,
    );
    if (current != null) _documents.remove(current.documentId);
    workspaceEpoch++;
    _emit(EudSourceState(document: document));
    return true;
  }

  void updateText(String text) {
    final current = _state.document;
    if (current == null) {
      throw StateError('No epScript document is open.');
    }
    updateDocumentText(current.documentId, text);
  }

  void restore(EudSourceDocument document) {
    if (documents.any(
      (d) =>
          d.isDirty ||
          (d.documentId != _state.document?.documentId && d.isUntitled),
    )) {
      throw StateError('Save or discard the current source first.');
    }
    workspaceEpoch++;
    _indexTimer?.cancel();
    _indexRequest++;
    indexPending = false;
    root = null;
    workspaceVerified = false;
    _disk.clear();
    index = null;
    conflicts.clear();
    workspaceError = null;
    _documents.clear();
    _emit(EudSourceState(document: document));
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
    return closeTab(current.documentId, discardChanges: true);
  }

  void dispose() {
    _disposed = true;
    _indexTimer?.cancel();
    _indexRequest++;
    translator?.cancel();
    _changes.close();
  }

  void _emit(EudSourceState nextState) {
    if (_disposed) return;
    final previous = nextState.document == null
        ? null
        : _documents[nextState.document!.documentId];
    _state = nextState;
    if (nextState.document case final d?) _documents[d.documentId] = d;
    if (!identical(previous, nextState.document)) _scheduleIndex();
    _announce();
  }

  String _newId(String prefix) {
    String id;
    do {
      id = '$prefix-${++_untitledSequence}';
    } while (_documents.containsKey(id));
    return id;
  }

  void _announce() {
    if (_disposed) return;
    revision++;
    _changes.add(_state);
  }
}
