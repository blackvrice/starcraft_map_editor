import '../triggers/trigger_script_syntax.dart';

abstract final class SourcePaths {
  static String relative(String path) {
    if (path.isEmpty ||
        path.length > 4096 ||
        path.contains('\\') ||
        path
            .split('/')
            .any(
              (s) =>
                  s.isEmpty ||
                  s == '.' ||
                  s == '..' ||
                  s.trim() != s ||
                  s.endsWith('.') ||
                  s.contains(RegExp(r'[<>:"|?*\x00-\x1f]')) ||
                  RegExp(
                    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
                    caseSensitive: false,
                  ).hasMatch(s),
            )) {
      throw const FormatException('SOURCE_PATH');
    }
    if (!const ['.eps', '.py', '.lua'].any(path.toLowerCase().endsWith)) {
      throw const FormatException('SOURCE_EXTENSION');
    }
    return path;
  }

  static String key(String path) =>
      path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '').toLowerCase();
}

final class SourceIndexIssue {
  const SourceIndexIssue(this.path, this.offset, this.code, this.detail);
  final String path, code, detail;
  final int offset;
}

final class SourceSearchHit {
  const SourceSearchHit(
    this.path,
    this.offset,
    this.line,
    this.column,
    this.excerpt,
  );
  final String path, excerpt;
  final int offset, line, column;
}

final class SourceSymbol {
  const SourceSymbol(this.name, this.offset);
  final String name;
  final int offset;
}

final class _Token {
  const _Token(this.text, this.offset, this.string);
  final String text;
  final int offset;
  final bool string;
}

final class _Import {
  const _Import(this.module, this.alias, this.name, this.offset, this.relative);
  final String module, alias;
  final String? name;
  final int offset, relative;
}

/// Static, advisory source navigation, never a Python/Lua interpreter or a full
/// parser. Strings/comments are tokenized first to avoid indexing fake imports.
final class SourceWorkspaceIndex {
  SourceWorkspaceIndex(Map<String, String> source)
    : texts = Map.unmodifiable(source) {
    if (texts.length > 256 ||
        texts.values.fold<int>(0, (n, s) => n + s.length) > 8 * 1024 * 1024) {
      throw const FormatException('SOURCE_INDEX_LIMIT');
    }
    for (final entry in texts.entries) {
      SourcePaths.relative(entry.key);
      _index(entry.key, entry.value);
    }
    for (final entry in imports.entries) {
      for (final item in entry.value) {
        final resolution = _resolve(entry.key, item);
        if (resolution.$2 != null) {
          issues.add(
            SourceIndexIssue(
              entry.key,
              item.offset,
              resolution.$2!,
              item.module,
            ),
          );
        }
      }
    }
  }
  final Map<String, String> texts;
  final symbols = <String, List<SourceSymbol>>{};
  final imports = <String, List<_Import>>{};
  final issues = <SourceIndexIssue>[];

  void _index(String path, String text) {
    if (text.length > TriggerScriptSyntax.maximumCharacters) {
      throw const FormatException('SOURCE_SIZE');
    }
    final language = path.toLowerCase().endsWith('.py')
        ? TriggerScriptLanguage.python
        : path.toLowerCase().endsWith('.lua')
        ? TriggerScriptLanguage.lua
        : TriggerScriptLanguage.epScript;
    final tokens = _lex(text, language);
    final found = <SourceSymbol>[], references = <_Import>[];
    final identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
    bool id(_Token t) => !t.string && identifier.hasMatch(t.text);
    var braces = 0;
    var scanned = 0, lineStart = 0;
    var leading = true;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      // Walk source positions once; repeated substring/lastIndexOf work is
      // quadratic for a long generated line with many tokens.
      for (var p = scanned; p < t.offset; p++) {
        final c = text.codeUnitAt(p);
        if (c == 10) {
          lineStart = p + 1;
          leading = true;
        } else if (c != 32 && c != 9 && c != 13) {
          leading = false;
        }
      }
      scanned = t.offset;
      if (t.string) continue;
      if (language == TriggerScriptLanguage.epScript) {
        if (t.text == '}') braces--;
        if (t.text == '{') {
          braces++;
          continue;
        }
      }
      final top =
          leading &&
          (language != TriggerScriptLanguage.python ||
              t.offset == lineStart ||
              t.offset == 0) &&
          braces == 0;
      if (const {
            'function',
            'def',
            'class',
            'object',
            'const',
            'var',
          }.contains(t.text) &&
          i + 1 < tokens.length &&
          id(tokens[i + 1]) &&
          top) {
        found.add(SourceSymbol(tokens[i + 1].text, tokens[i + 1].offset));
      }
      if (language == TriggerScriptLanguage.python &&
          top &&
          id(t) &&
          i + 1 < tokens.length &&
          tokens[i + 1].text == '=') {
        found.add(SourceSymbol(t.text, t.offset));
      }
      if (t.text == 'import' && top) {
        var j = i + 1;
        do {
          final module = StringBuffer();
          while (j < tokens.length &&
              (id(tokens[j]) || tokens[j].text == '.') &&
              tokens[j].text != 'as') {
            module.write(tokens[j++].text);
          }
          if (module.isNotEmpty) {
            final alias =
                j + 1 < tokens.length &&
                    tokens[j].text == 'as' &&
                    id(tokens[j + 1])
                ? tokens[j + 1].text
                : module.toString();
            references.add(
              _Import(module.toString(), alias, null, t.offset, 0),
            );
            if (j + 1 < tokens.length &&
                tokens[j].text == 'as' &&
                id(tokens[j + 1])) {
              j += 2;
            }
          }
          if (j >= tokens.length || tokens[j].text != ',') break;
          j++;
        } while (j < tokens.length);
      }
      if (language == TriggerScriptLanguage.python && t.text == 'from' && top) {
        var j = i + 1, dots = 0;
        while (j < tokens.length && tokens[j].text == '.') {
          dots++;
          j++;
        }
        final module = StringBuffer();
        while (j < tokens.length &&
            tokens[j].text != 'import' &&
            (id(tokens[j]) || tokens[j].text == '.')) {
          module.write(tokens[j++].text);
        }
        if (j < tokens.length && tokens[j].text == 'import') {
          j++;
          while (j < tokens.length &&
              tokens[j].text != '\n' &&
              tokens[j].text != ';') {
            if (id(tokens[j]) || tokens[j].text == '*') {
              final name = tokens[j++].text;
              var alias = name;
              if (j + 1 < tokens.length &&
                  tokens[j].text == 'as' &&
                  id(tokens[j + 1])) {
                alias = tokens[j + 1].text;
                j += 2;
              }
              references.add(
                _Import(module.toString(), alias, name, t.offset, dots),
              );
            } else if (tokens[j].text == ',') {
              j++;
            } else {
              break;
            }
          }
        }
      }
      if (language == TriggerScriptLanguage.lua && t.text == 'require') {
        var j = i + 1;
        if (j < tokens.length && tokens[j].text == '(') j++;
        if (j < tokens.length &&
            tokens[j].string &&
            (j + 1 == tokens.length ||
                const {')', '\n', ';'}.contains(tokens[j + 1].text))) {
          final alias = i >= 2 && tokens[i - 1].text == '=' && id(tokens[i - 2])
              ? tokens[i - 2].text
              : tokens[j].text;
          references.add(_Import(tokens[j].text, alias, null, t.offset, 0));
        }
      }
    }
    symbols[path] = List.unmodifiable(found);
    imports[path] = List.unmodifiable(references);
  }

  (String?, String?) _resolve(String path, _Import item) {
    final parts = path.split('/')..removeLast();
    if (item.module.contains('/') ||
        item.module.contains('\\') ||
        (item.module.isNotEmpty &&
            !RegExp(
              r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$',
            ).hasMatch(item.module))) {
      return (null, 'SOURCE_IMPORT_PATH');
    }
    if (item.relative > 0) {
      if (item.relative - 1 > parts.length) {
        return (null, 'SOURCE_IMPORT_OUTSIDE_ROOT');
      }
      for (var i = 1; i < item.relative; i++) {
        parts.removeLast();
      }
    }
    final module =
        (item.module.isEmpty && item.name != null && item.name != '*'
                ? item.name!
                : item.module)
            .replaceAll('.', '/');
    final bases = <String>{
      if (item.relative > 0 || !path.toLowerCase().endsWith('.py'))
        [...parts, if (module.isNotEmpty) module].join('/'),
      if (item.relative == 0) module,
    };
    final candidates = <String>{};
    for (final base in bases) {
      for (final ext in ['eps', 'py', 'lua']) {
        for (final candidate in ['$base.$ext', '$base/__init__.$ext']) {
          candidates.addAll(
            texts.keys.where(
              (p) => SourcePaths.key(p) == SourcePaths.key(candidate),
            ),
          );
        }
      }
    }
    if (candidates.length > 1) return (null, 'SOURCE_IMPORT_AMBIGUOUS');
    if (candidates.isEmpty) {
      return (null, item.relative > 0 ? 'SOURCE_IMPORT_MISSING' : null);
    }
    return (candidates.single, null);
  }

  List<String> completions(String path) {
    final result = <String>{
      for (final s in symbols[path] ?? <SourceSymbol>[]) s.name,
    };
    for (final item in imports[path] ?? <_Import>[]) {
      final target = _resolve(path, item).$1;
      if (target == null) continue;
      for (final s in symbols[target] ?? <SourceSymbol>[]) {
        if (item.name == null || item.module.isEmpty) {
          result.add('${item.alias}.${s.name}');
        } else if (item.name == '*') {
          result.add(s.name);
        } else if (item.name == s.name) {
          result.add(item.alias);
        }
      }
    }
    return result.toList()..sort();
  }

  List<SourceSearchHit> search(String query, {bool caseSensitive = false}) {
    if (query.isEmpty || query.length > 256) return const [];
    final result = <SourceSearchHit>[];
    for (final entry in texts.entries) {
      final matcher = RegExp(
        RegExp.escape(query),
        caseSensitive: caseSensitive,
      );
      var line = 1, start = 0, scanned = 0;
      for (final match in matcher.allMatches(entry.value)) {
        final at = match.start;
        for (var p = scanned; p < at; p++) {
          if (entry.value.codeUnitAt(p) == 10) {
            line++;
            start = p + 1;
          }
        }
        scanned = at;
        final end = entry.value.indexOf('\n', at);
        result.add(
          SourceSearchHit(
            entry.key,
            at,
            line,
            at - start + 1,
            entry.value
                .substring(
                  at,
                  (end < 0 ? entry.value.length : end).clamp(
                    at,
                    (at + 180).clamp(at, entry.value.length),
                  ),
                )
                .trim(),
          ),
        );
        if (result.length >= 500) return result;
      }
    }
    return result;
  }
}

List<_Token> _lex(String source, TriggerScriptLanguage language) {
  final tokens = <_Token>[];
  final first = RegExp(r'[A-Za-z_]'), rest = RegExp(r'[A-Za-z0-9_]');
  final luaLong = RegExp(r'^(?:--)?\[(=*)\[');
  var at = 0;
  while (at < source.length) {
    if (tokens.length >= 200000) {
      throw const FormatException('SOURCE_TOKEN_LIMIT');
    }
    final start = at, c = source[at];
    if (c == '\n') {
      tokens.add(_Token(c, at++, false));
      continue;
    }
    if (c.trim().isEmpty) {
      at++;
      continue;
    }
    if (language == TriggerScriptLanguage.lua &&
        (c == '[' || source.startsWith('--[', at))) {
      final long = luaLong.firstMatch(
        source.substring(at, (at + 32).clamp(at, source.length)),
      );
      if (long != null) {
        final delimiter = ']${long.group(1)!}]';
        final end = source.indexOf(delimiter, at + long.end);
        at = end < 0 ? source.length : end + delimiter.length;
        continue;
      }
    }
    if (source.startsWith(language.comment, at)) {
      final end = source.indexOf('\n', at);
      at = end < 0 ? source.length : end;
      continue;
    }
    if (language == TriggerScriptLanguage.epScript &&
        source.startsWith('/*', at)) {
      final end = source.indexOf('*/', at + 2);
      at = end < 0 ? source.length : end + 2;
      continue;
    }
    if (language == TriggerScriptLanguage.lua && source.startsWith('[[', at)) {
      final end = source.indexOf(']]', at + 2);
      at = end < 0 ? source.length : end + 2;
      continue;
    }
    if (c == '"' || c == "'") {
      final triple =
          language == TriggerScriptLanguage.python &&
          source.startsWith(c * 3, at);
      final quote = triple ? c * 3 : c;
      at += quote.length;
      final begin = at;
      while (at < source.length && !source.startsWith(quote, at)) {
        if (source[at] == '\\') {
          at = (at + 2).clamp(0, source.length);
        } else {
          at++;
        }
      }
      final value = source.substring(begin, at);
      at = (at + quote.length).clamp(0, source.length);
      tokens.add(_Token(value, start, true));
      continue;
    }
    if (first.hasMatch(c)) {
      at++;
      while (at < source.length && rest.hasMatch(source[at])) {
        at++;
      }
      tokens.add(_Token(source.substring(start, at), start, false));
      continue;
    }
    tokens.add(_Token(c, at++, false));
  }
  return tokens;
}
