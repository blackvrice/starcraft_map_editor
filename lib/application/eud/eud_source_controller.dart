import 'dart:async';
import 'dart:isolate';
import '../../domain/eud/portable_eud_script.dart';

import 'eud_source_document.dart';
import '../ports/trigger_script_gateway.dart';
import '../../domain/triggers/trigger_script_syntax.dart';
import '../ports/eud_source_translation_gateway.dart';

final class EudSourceState {
  const EudSourceState({required this.document});

  const EudSourceState.closed() : document = null;

  final EudSourceDocument? document;

  bool get hasDocument => document != null;
}

final class EudSourceController {
  EudSourceController({this.files, this.translator})
    : _state = const EudSourceState.closed();
  final TriggerScriptFiles? files;
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
    final old = _state.document;
    if ((old?.isDirty ?? false) ||
        ((old?.isUntitled ?? false) && old!.text.isNotEmpty)) {
      throw StateError('SCRIPT_DIRTY');
    }
    final file = await files?.open();
    if (file == null) return false;
    if (_disposed || !identical(old, _state.document)) {
      throw StateError('SCRIPT_SOURCE_CHANGED');
    }
    if (file.language == TriggerScriptLanguage.lua) {
      throw StateError('EUD_NATIVE_LUA_UNSUPPORTED');
    }
    return open(sourcePath: file.path, text: file.text);
  }

  Future<bool> saveNew() async {
    final current = _state.document;
    if (current == null || files == null) return false;
    final path = await files!.saveNew(current.text, current.language);
    if (path == null) return false;
    // A late Save As must not mark newer text as saved.
    if (!_disposed && identical(current, _state.document)) {
      markSaved(sourcePath: path);
    }
    return true;
  }

  bool changeEmptyLanguage(TriggerScriptLanguage language) {
    final current = _state.document;
    if (current == null ||
        !current.isUntitled ||
        current.text.isNotEmpty ||
        language == TriggerScriptLanguage.lua) {
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

  void restore(EudSourceDocument document) {
    if (_state.document?.isDirty ?? false) {
      throw StateError('Save or discard the current source first.');
    }
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
    _emit(const EudSourceState.closed());
    return true;
  }

  void dispose() {
    _disposed = true;
    translator?.cancel();
    _changes.close();
  }

  void _emit(EudSourceState nextState) {
    _state = nextState;
    _changes.add(nextState);
  }
}
