enum TriggerScriptLanguage { epScript, python, lua }

extension TriggerScriptLanguageSyntax on TriggerScriptLanguage {
  String get extension => switch (this) {
    TriggerScriptLanguage.epScript => 'eps',
    TriggerScriptLanguage.python => 'py',
    TriggerScriptLanguage.lua => 'lua',
  };
  String get comment => switch (this) {
    TriggerScriptLanguage.epScript => '//',
    TriggerScriptLanguage.python => '#',
    TriggerScriptLanguage.lua => '--',
  };
  String boolean(bool value) => this == TriggerScriptLanguage.python
      ? (value ? 'True' : 'False')
      : (value ? 'true' : 'false');
}

final class TriggerScriptDiagnostic implements Exception {
  const TriggerScriptDiagnostic(this.code, this.offset, [this.detail = '']);
  final String code, detail;

  /// UTF-16 code unit offset, matching Dart's text editor selection.
  final int offset;
  ({int line, int column}) position(String source) {
    final before = source.substring(0, offset.clamp(0, source.length));
    final lines = before.split('\n');
    return (line: lines.length, column: lines.last.length + 1);
  }

  @override
  String toString() => '$code@$offset${detail.isEmpty ? "" : ": $detail"}';
}

final class TriggerScriptCall {
  TriggerScriptCall(this.name, List<Object> arguments, this.offset)
    : arguments = List.unmodifiable(arguments);
  final String name;
  final List<Object> arguments;
  final int offset;
}

/// Parser for the editor's versioned declaration API, not a general language
/// interpreter. Calls/literals only; no identifier evaluation or host runtime.
final class TriggerScriptSyntax {
  TriggerScriptSyntax(this.source, this.language);
  static const maximumCharacters = 1024 * 1024;
  static const maximumNodes = 100000;
  static const maximumDepth = 8;
  final String source;
  final TriggerScriptLanguage language;
  int _at = 0, _nodes = 0;

  List<TriggerScriptCall> parse() {
    if (source.length > maximumCharacters) _fail('SCRIPT_SIZE', 0);
    final result = <TriggerScriptCall>[];
    _space();
    while (_at < source.length) {
      if (language == TriggerScriptLanguage.python) {
        final lineStart = _at == 0 ? 0 : source.lastIndexOf('\n', _at - 1) + 1;
        final prefix = source.substring(lineStart, _at);
        if (prefix.isNotEmpty && prefix.trim().isEmpty) {
          _fail('SCRIPT_PYTHON_INDENT', _at);
        }
      }
      final value = _value(0);
      if (value is! TriggerScriptCall) _fail('SCRIPT_STATEMENT', _at);
      result.add(value);
      final end = _at;
      _space();
      if (_take(';')) {
        _space();
      } else if (language == TriggerScriptLanguage.epScript ||
          (_at < source.length && !source.substring(end, _at).contains('\n'))) {
        _fail('SCRIPT_SEPARATOR', _at);
      }
    }
    return List.unmodifiable(result);
  }

  Object _value(int depth) {
    _space();
    final start = _at;
    if (depth > maximumDepth || ++_nodes > maximumNodes) {
      _fail('SCRIPT_BUDGET', start);
    }
    if (_at >= source.length) _fail('SCRIPT_EOF', start);
    final c = source.codeUnitAt(_at);
    if (c >= 48 && c <= 57) {
      final hex = source.startsWith('0x', _at);
      if (hex) _at += 2;
      final digits = _at;
      while (_at < source.length && _digit(source.codeUnitAt(_at), hex)) {
        _at++;
      }
      final count = _at - digits;
      if (count == 0 ||
          count > (hex ? 8 : 10) ||
          (!hex && count > 1 && source.codeUnitAt(start) == 48)) {
        _fail('SCRIPT_INTEGER', start);
      }
      final value = int.parse(
        source.substring(digits, _at),
        radix: hex ? 16 : 10,
      );
      if (value > 0xffffffff) _fail('SCRIPT_INTEGER', start);
      return value;
    }
    if (c == 34 || c == 39) {
      _at++;
      final begin = _at;
      while (_at < source.length && source.codeUnitAt(_at) != c) {
        final n = source.codeUnitAt(_at);
        if (n < 32 || n == 92) _fail('SCRIPT_STRING', _at);
        _at++;
      }
      if (_at == source.length) _fail('SCRIPT_STRING', start);
      final text = source.substring(begin, _at++);
      return text;
    }
    if (!_letter(c)) _fail('SCRIPT_UNSUPPORTED', start);
    _at++;
    while (_at < source.length &&
        (_letter(source.codeUnitAt(_at)) ||
            _digit(source.codeUnitAt(_at), false))) {
      _at++;
    }
    final name = source.substring(start, _at);
    if (name == language.boolean(true)) return true;
    if (name == language.boolean(false)) return false;
    final nameEnd = _at;
    _space();
    if (language == TriggerScriptLanguage.python &&
        source.substring(nameEnd, _at).contains('\n')) {
      _fail('SCRIPT_PYTHON_LINE', nameEnd);
    }
    if (!_take('(')) _fail('SCRIPT_UNSUPPORTED', start, name);
    final args = <Object>[];
    _space();
    if (_take(')')) return TriggerScriptCall(name, args, start);
    while (true) {
      args.add(_value(depth + 1));
      _space();
      if (_take(')')) break;
      if (!_take(',')) _fail('SCRIPT_ARGUMENT_SEPARATOR', _at);
      _space();
      if (_at < source.length && source[_at] == ')') {
        _fail('SCRIPT_TRAILING_COMMA', _at);
      }
    }
    return TriggerScriptCall(name, args, start);
  }

  void _space() {
    while (_at < source.length) {
      final c = source.codeUnitAt(_at);
      if (c == 32 || c == 9 || c == 13 || c == 10) {
        _at++;
        continue;
      }
      if (source.startsWith(language.comment, _at)) {
        final end = source.indexOf('\n', _at);
        _at = end < 0 ? source.length : end;
      } else if (language == TriggerScriptLanguage.epScript &&
          source.startsWith('/*', _at)) {
        final end = source.indexOf('*/', _at + 2);
        if (end < 0) _fail('SCRIPT_COMMENT', _at);
        _at = end + 2;
      } else {
        return;
      }
    }
  }

  bool _take(String value) {
    if (!source.startsWith(value, _at)) return false;
    _at += value.length;
    return true;
  }

  static bool _letter(int c) =>
      c >= 65 && c <= 90 || c >= 97 && c <= 122 || c == 95;
  static bool _digit(int c, bool hex) =>
      c >= 48 && c <= 57 || hex && (c >= 65 && c <= 70 || c >= 97 && c <= 102);
  Never _fail(String code, int at, [String detail = '']) =>
      throw TriggerScriptDiagnostic(code, at, detail);
}
