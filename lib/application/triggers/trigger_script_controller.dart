import 'dart:async';
import 'package:crypto/crypto.dart';
import '../../domain/chk/raw_chk_encoder.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/triggers/trigger_script.dart';
import '../editing/object_editing_controller.dart';
import '../ports/trigger_script_gateway.dart';
import 'trigger_script_drafts.dart';
export 'trigger_script_drafts.dart';

final class TriggerScriptController {
  TriggerScriptController({
    required this.editing,
    required this.gateway,
    this.files,
  }) {
    _maps = editing.openMapController.changes.listen((_) {
      if (!identical(baseline, currentDocument)) {
        _invalidate();
        error = 'SCRIPT_STALE_MAP';
        _notify();
      }
    });
  }
  final ObjectEditingController editing;
  final TriggerScriptGateway gateway;
  final TriggerScriptFiles? files;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  late final StreamSubscription<Object?> _maps;
  static int _sequence = 0;
  int _revision = 0;
  String? _operation;
  bool _disposed = false, busy = false;
  bool _initialized = false;
  String text = '', _loadedText = '';
  TriggerScriptLanguage language = TriggerScriptLanguage.epScript;
  TriggerScriptLanguage? target;
  RawChkDocument? baseline;
  TriggerScriptAnalysis? preview;
  String? error;
  final _history = <TriggerScriptDraft>[];
  final _exportedHistory = <TriggerScriptDraft>{};
  TriggerScriptDraft? _savedCurrent;
  List<TriggerScriptDraft> get history => List.unmodifiable(_history);
  bool get dirty => text != _loadedText;
  bool get currentNeedsSave =>
      dirty &&
      (_savedCurrent?.text != text || _savedCurrent?.language != language);
  bool get hasPendingSources =>
      currentNeedsSave ||
      _history.any((draft) => !_exportedHistory.contains(draft));
  RawChkDocument? get currentDocument =>
      editing.openMapController.state.session?.rawDocument;
  bool get stale => !identical(baseline, currentDocument);
  bool get canApply =>
      !busy && !stale && preview?.isSuccess == true && target == language;

  Future<bool> open() async {
    final recovered = editing.triggerDrafts.value;
    if (recovered == null) return reload();
    final current = currentDocument;
    baseline =
        current != null &&
            sha256.convert(const RawChkEncoder().encode(current)) ==
                sha256.convert(const RawChkEncoder().encode(recovered.baseline))
        ? current
        : recovered.baseline;
    text = recovered.current.text;
    language = recovered.current.language;
    _loadedText = recovered.loadedText;
    _history.addAll(recovered.history);
    _initialized = true;
    error = stale ? 'SCRIPT_STALE_MAP' : null;
    _notify();
    return true;
  }

  void discardRecovery() => editing.triggerDrafts.update(null);

  void updateText(String value) {
    if (_disposed || value == text) return;
    _invalidate();
    text = value;
    error = null;
    _notify();
  }

  void _invalidate() {
    _revision++;
    if (_operation case final operation?) gateway.cancel(operation);
    _operation = null;
    busy = false;
    preview = null;
    target = null;
  }

  void _archive() {
    if (text.isEmpty ||
        text == _loadedText ||
        _history.any((d) => d.text == text && d.language == language)) {
      return;
    }
    if (_history.length >= 8) {
      final saved = _history.where(_exportedHistory.contains).firstOrNull;
      if (saved == null) throw StateError('SCRIPT_HISTORY_LIMIT');
      _history.remove(saved);
      _exportedHistory.remove(saved);
    }
    final draft = TriggerScriptDraft(text, language);
    _history.add(draft);
    if (_savedCurrent?.text == text && _savedCurrent?.language == language) {
      _exportedHistory.add(draft);
    }
  }

  Future<bool> reload({bool keepDraft = false}) async {
    if (_disposed) return false;
    if (dirty && !keepDraft) throw StateError('SCRIPT_DIRTY');
    if (keepDraft) _archive();
    _invalidate();
    _initialized = true;
    baseline = currentDocument;
    return _analyze(initial: true);
  }

  Future<bool> analyze({TriggerScriptLanguage? convertTo}) =>
      _analyze(convertTo: convertTo);

  Future<bool> _analyze({
    bool initial = false,
    TriggerScriptLanguage? convertTo,
  }) async {
    if (_disposed) return false;
    _invalidate();
    final document = baseline;
    if (document == null ||
        stale ||
        editing.openMapController.state.session!.requiresRestrictedEditing) {
      error = 'SCRIPT_STALE_MAP';
      _notify();
      return false;
    }
    final revision = _revision, operation = 'trigger-script-${++_sequence}';
    final selected = language, source = text;
    _operation = operation;
    busy = true;
    error = null;
    _notify();
    try {
      final result = await gateway.analyze(
        operationId: operation,
        document: document,
        language: selected,
        source: initial ? null : source,
        target: convertTo ?? selected,
      );
      if (_disposed || revision != _revision || stale) return false;
      if (!result.isSuccess) {
        preview = result;
        error = result.diagnostic?.toString() ?? 'SCRIPT_ANALYSIS_FAILED';
        return false;
      }
      if (initial) {
        text = result.generated!;
        _loadedText = text;
      }
      preview = result;
      target = convertTo ?? selected;
      return true;
    } on Object catch (e) {
      if (!_disposed && revision == _revision) error = '$e';
      return false;
    } finally {
      if (!_disposed && revision == _revision) {
        _operation = null;
        busy = false;
        _notify();
      }
    }
  }

  bool acceptConversion() {
    if (_disposed ||
        busy ||
        stale ||
        preview?.isSuccess != true ||
        target == null ||
        target == language) {
      return false;
    }
    _archive();
    text = preview!.generated!;
    language = target!;
    _invalidate();
    _notify();
    return true;
  }

  Future<bool> apply({bool allowDeletion = false}) async {
    if (!canApply) return false;
    final program = preview!.program!;
    if (program.opaqueDeletions > 0 && !allowDeletion) {
      throw StateError('SCRIPT_DELETION_CONFIRMATION');
    }
    _archive();
    editing.applyTriggers(
      expectedDocument: baseline!,
      records: program.triggers,
    );
    return reload(keepDraft: true);
  }

  Future<bool> importSource({bool keepDraft = false}) async {
    if (_disposed || busy || files == null) return false;
    if (dirty && !keepDraft) throw StateError('SCRIPT_DIRTY');
    final revision = _revision;
    final file = await files!.open();
    if (_disposed || file == null || revision != _revision) return false;
    _archive();
    _invalidate();
    language = file.language;
    text = file.text;
    _notify();
    return analyze();
  }

  Future<String?> exportSource({TriggerScriptDraft? draft}) async {
    if (_disposed || files == null) return null;
    final chosen = draft ?? TriggerScriptDraft(text, language);
    final path = await files!.saveNew(chosen.text, chosen.language);
    if (!_disposed && path != null) {
      if (draft == null) _savedCurrent = chosen;
      _exportedHistory.addAll(
        _history.where(
          (d) => d.text == chosen.text && d.language == chosen.language,
        ),
      );
      _notify();
    }
    return path;
  }

  Future<bool> exportPending() async {
    if (currentNeedsSave && await exportSource() == null) return false;
    for (final draft in List.of(_history)) {
      if (!_exportedHistory.contains(draft) &&
          await exportSource(draft: draft) == null) {
        return false;
      }
    }
    return !hasPendingSources;
  }

  void _notify() {
    if (!_disposed) {
      if (_initialized && baseline != null) {
        try {
          editing.triggerDrafts.update(
            hasPendingSources
                ? TriggerScriptRecovery(
                    baseline: baseline!,
                    current: TriggerScriptDraft(text, language),
                    loadedText: _loadedText,
                    history: _history.where(
                      (d) => !_exportedHistory.contains(d),
                    ),
                  )
                : null,
          );
        } on FormatException {
          // Keep the last checkpoint and exact editor text, never truncate.
          error = 'SCRIPT_RECOVERY_LIMIT';
        }
      }
      _changes.add(null);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _invalidate();
    await _maps.cancel();
    await _changes.close();
  }
}
