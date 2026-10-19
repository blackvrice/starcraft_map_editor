import '../../domain/triggers/trigger_script_syntax.dart';

final class EudSourceDocument {
  EudSourceDocument._({
    required this.documentId,
    required this.fileName,
    required this.sourcePath,
    required this.savedText,
    required this.text,
    required this.revision,
  });

  factory EudSourceDocument.untitled({
    required String documentId,
    String fileName = 'main.eps',
    String initialText = '',
  }) {
    return EudSourceDocument._(
      documentId: _requireDocumentId(documentId),
      fileName: _requireEpsFileName(fileName),
      sourcePath: null,
      savedText: initialText,
      text: initialText,
      revision: 0,
    );
  }

  factory EudSourceDocument.opened({
    required String documentId,
    required String sourcePath,
    required String text,
  }) {
    final validatedPath = _requireAbsoluteEpsPath(sourcePath);
    return EudSourceDocument._(
      documentId: _requireDocumentId(documentId),
      fileName: _fileName(validatedPath),
      sourcePath: validatedPath,
      savedText: text,
      text: text,
      revision: 0,
    );
  }

  final String documentId;
  final String fileName;
  final String? sourcePath;
  final String savedText;
  final String text;
  final int revision;

  bool get isDirty => text != savedText;
  bool get isUntitled => sourcePath == null;
  int get lineCount => '\n'.allMatches(text).length + 1;
  TriggerScriptLanguage get language => _language(fileName);

  EudSourceDocument withText(String nextText) {
    if (nextText == text) {
      return this;
    }
    return EudSourceDocument._(
      documentId: documentId,
      fileName: fileName,
      sourcePath: sourcePath,
      savedText: savedText,
      text: nextText,
      revision: revision + 1,
    );
  }

  EudSourceDocument markSaved({String? savedPath}) {
    final resolvedPath = savedPath == null
        ? sourcePath
        : _requireAbsoluteEpsPath(savedPath);
    if (resolvedPath == null) {
      throw StateError(
        'An untitled epScript document needs a path before it can be saved.',
      );
    }
    if (_language(resolvedPath) != language) {
      throw ArgumentError('Save As must retain the source language.');
    }
    return EudSourceDocument._(
      documentId: documentId,
      fileName: _fileName(resolvedPath),
      sourcePath: resolvedPath,
      savedText: text,
      text: text,
      revision: revision + 1,
    );
  }

  /// A save may finish after more typing. Advance only the disk baseline, not
  /// the editor buffer, so the newer revision remains dirty and can be saved.
  EudSourceDocument withSavedText(String persistedText) => EudSourceDocument._(
    documentId: documentId,
    fileName: fileName,
    sourcePath: sourcePath,
    savedText: persistedText,
    text: text,
    revision: revision + 1,
  );
}

String _requireDocumentId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed != value ||
      value.codeUnits.any((codeUnit) => codeUnit < 0x20)) {
    throw ArgumentError.value(
      value,
      'documentId',
      'The document ID must be nonblank and contain no control characters.',
    );
  }
  return value;
}

String _requireEpsFileName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed != value ||
      value.contains('/') ||
      value.contains(r'\') ||
      value.codeUnits.any((codeUnit) => codeUnit < 0x20) ||
      !_sourceExtension(value)) {
    throw ArgumentError.value(
      value,
      'fileName',
      'The source file name must be a single .eps, .py or .lua path segment.',
    );
  }
  return value;
}

String _requireAbsoluteEpsPath(String value) {
  final trimmed = value.trim();
  final isAbsoluteWindowsPath = RegExp(
    r'^(?:[a-zA-Z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$))',
  ).hasMatch(value);
  if (trimmed.isEmpty ||
      trimmed != value ||
      !isAbsoluteWindowsPath ||
      !_sourceExtension(value) ||
      value.startsWith(r'\\?\') ||
      value.startsWith(r'\\.\') ||
      value.split(RegExp(r'[\\/]')).any((s) => s == '..' || s == '.') ||
      value.codeUnits.any((c) => c < 0x20)) {
    throw ArgumentError.value(
      value,
      'sourcePath',
      'The source path must be an absolute Windows .eps, .py or .lua path.',
    );
  }
  return value;
}

String _fileName(String path) {
  return path.replaceAll(r'\', '/').split('/').last;
}

bool _sourceExtension(String value) =>
    const ['.eps', '.py', '.lua'].any(value.toLowerCase().endsWith);

TriggerScriptLanguage _language(String path) =>
    path.toLowerCase().endsWith('.py')
    ? TriggerScriptLanguage.python
    : path.toLowerCase().endsWith('.lua')
    ? TriggerScriptLanguage.lua
    : TriggerScriptLanguage.epScript;
