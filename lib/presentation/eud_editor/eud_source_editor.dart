import '../localization/l10n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ep_script_text_controller.dart';

import '../../application/eud/eud_source_controller.dart';
import '../../application/eud/eud_source_document.dart';

class EudSourceEditor extends StatefulWidget {
  const EudSourceEditor({
    required this.document,
    required this.sourceController,
    super.key,
  });

  final EudSourceDocument document;
  final EudSourceController sourceController;

  @override
  State<EudSourceEditor> createState() => _EudSourceEditorState();
}

class _EudSourceEditorState extends State<EudSourceEditor> {
  late final EpScriptTextController _textController;
  late final ScrollController _editorScrollController;
  late final ScrollController _gutterScrollController;
  late final FocusNode _focusNode;
  bool _synchronizing = false;
  bool _hideCompletions = false;
  int _completionIndex = 0;

  @override
  void initState() {
    super.initState();
    _textController = EpScriptTextController(text: widget.document.text)
      ..addListener(_handleTextChanged);
    _editorScrollController = ScrollController()
      ..addListener(_synchronizeGutter);
    _gutterScrollController = ScrollController();
    _focusNode = FocusNode(onKeyEvent: _handleKey);
  }

  @override
  void didUpdateWidget(EudSourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_textController.text == widget.document.text) {
      return;
    }
    final selection = _textController.selection;
    final offset = math.min(selection.baseOffset, widget.document.text.length);
    _synchronizing = true;
    _textController.value = TextEditingValue(
      text: widget.document.text,
      selection: TextSelection.collapsed(offset: math.max(0, offset)),
    );
    _synchronizing = false;
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleTextChanged)
      ..dispose();
    _editorScrollController.dispose();
    _gutterScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    _hideCompletions = false;
    _completionIndex = 0;
    if (!_synchronizing) {
      widget.sourceController.updateText(_textController.text);
    }
    if (mounted) {
      setState(() {});
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final suggestions = _textController.completions;
    if (event.logicalKey == LogicalKeyboardKey.space &&
        HardwareKeyboard.instance.isControlPressed) {
      setState(() => _hideCompletions = false);
      return KeyEventResult.handled;
    }
    if (!_hideCompletions && suggestions.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _hideCompletions = true);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(
          () => _completionIndex =
              (_completionIndex +
                  (event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
              suggestions.length,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        _textController.complete(
          suggestions[_completionIndex % suggestions.length],
        );
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _insertStarter() {
    final selection = _textController.selection;
    final start = selection.isValid
        ? selection.end
        : _textController.text.length;
    final inserted = '${start > 0 ? '\n' : ''}$epScriptStarter';
    _textController.value = TextEditingValue(
      text: _textController.text.replaceRange(start, start, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    _focusNode.requestFocus();
  }

  void _showHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.epScriptHelpTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Text(context.l10n.epScriptHelpBody),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.eudCancel),
        ),
      ],
    ),
  );

  void _synchronizeGutter() {
    if (!_gutterScrollController.hasClients) {
      return;
    }
    final target = _editorScrollController.offset.clamp(
      0.0,
      _gutterScrollController.position.maxScrollExtent,
    );
    _gutterScrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final cursor = _cursorPosition(
      _textController.text,
      _textController.selection.baseOffset,
    );

    return Material(
      key: const Key('eud-source-workspace'),
      color: const Color(0xFF0D1117),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorHeader(
            document: document,
            onExample: _insertStarter,
            onHelp: _showHelp,
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LineNumberGutter(
                  lineCount: document.lineCount,
                  scrollController: _gutterScrollController,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: TextField(
                    key: const Key('eud-source-editor'),
                    controller: _textController,
                    scrollController: _editorScrollController,
                    focusNode: _focusNode,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: const TextStyle(
                      color: Color(0xFFD7DEE9),
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(14, 16, 18, 24),
                      hintText: context.l10n.editorWriteEpScriptHere,
                      hintStyle: TextStyle(color: Color(0xFF596579)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_hideCompletions && _textController.completions.isNotEmpty)
            SizedBox(
              key: const Key('ep-script-completions'),
              height: 112,
              child: ListView.builder(
                itemCount: _textController.completions.length,
                itemExtent: 32,
                itemBuilder: (context, index) {
                  final symbol = _textController.completions[index];
                  return ListTile(
                    key: Key('ep-script-complete-$symbol'),
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -4),
                    selected: index == _completionIndex,
                    leading: const Icon(Icons.code, size: 16),
                    title: Text(
                      symbol,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      _textController.complete(symbol);
                      _focusNode.requestFocus();
                    },
                  );
                },
              ),
            ),
          const Divider(height: 1),
          _EditorFooter(document: document, cursor: cursor),
        ],
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.document,
    required this.onExample,
    required this.onHelp,
  });

  final EudSourceDocument document;
  final VoidCallback onExample, onHelp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.code_rounded, size: 18, color: Color(0xFF70A1FF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                document.fileName,
                key: const Key('eud-source-file-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              key: const Key('ep-script-example'),
              tooltip: context.l10n.epScriptInsertExample,
              onPressed: onExample,
              icon: const Icon(Icons.post_add),
            ),
            IconButton(
              key: const Key('ep-script-help'),
              tooltip: context.l10n.epScriptHelpTitle,
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline),
            ),
            _DirtyBadge(isDirty: document.isDirty),
          ],
        ),
      ),
    );
  }
}

class _DirtyBadge extends StatelessWidget {
  const _DirtyBadge({required this.isDirty});

  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    final color = isDirty ? const Color(0xFFFFB454) : const Color(0xFF68D391);
    return Container(
      key: const Key('eud-source-dirty-state'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        isDirty ? context.l10n.editorModified : context.l10n.editorClean,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LineNumberGutter extends StatelessWidget {
  const _LineNumberGutter({
    required this.lineCount,
    required this.scrollController,
  });

  final int lineCount;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: ColoredBox(
        color: const Color(0xFF111720),
        child: IgnorePointer(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(0, 16, 8, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var line = 1; line <= lineCount; line++)
                  Text(
                    '$line',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF596579),
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorFooter extends StatelessWidget {
  const _EditorFooter({required this.document, required this.cursor});

  final EudSourceDocument document;
  final ({int line, int column}) cursor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ColoredBox(
        color: const Color(0xFF151B24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message:
                      document.sourcePath ?? context.l10n.editorInMemoryDraft,
                  child: Text(
                    document.isUntitled
                        ? context.l10n.editorInMemoryDraft
                        : document.sourcePath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8994A8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                context.l10n.editorLnCol(
                  (cursor.line).toString(),
                  (cursor.column).toString(),
                ),
                key: const Key('eud-source-cursor'),
                style: const TextStyle(color: Color(0xFFB4C0D4), fontSize: 11),
              ),
              const SizedBox(width: 14),
              const Text(
                'epScript',
                style: TextStyle(color: Color(0xFFB4C0D4), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({int line, int column}) _cursorPosition(String text, int offset) {
  final safeOffset = offset.clamp(0, text.length);
  final beforeCursor = text.substring(0, safeOffset);
  final line = '\n'.allMatches(beforeCursor).length + 1;
  final lastNewline = beforeCursor.lastIndexOf('\n');
  final column = safeOffset - lastNewline;
  return (line: line, column: column);
}
