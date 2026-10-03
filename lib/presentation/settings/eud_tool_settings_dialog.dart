import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/settings/eud_tool_settings_controller.dart';

class EudToolSettingsDialog extends StatefulWidget {
  const EudToolSettingsDialog({required this.controller, super.key});
  final EudToolSettingsController controller;
  @override
  State<EudToolSettingsDialog> createState() => _EudToolSettingsDialogState();
}

class _EudToolSettingsDialogState extends State<EudToolSettingsDialog> {
  late final TextEditingController _path;
  @override
  void initState() {
    super.initState();
    _path = TextEditingController(text: widget.controller.state.path ?? '');
    unawaited(
      widget.controller.load().then((_) {
        if (mounted && _path.text.isEmpty) {
          _path.text = widget.controller.state.path ?? '';
        }
      }),
    );
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<EudToolSettingsState>(
    stream: widget.controller.changes,
    initialData: widget.controller.state,
    builder: (context, snapshot) {
      final state = snapshot.data ?? widget.controller.state;
      final tool = state.result?.tool;
      return AlertDialog(
        title: Text(context.l10n.editorEUDTools),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context
                      .l10n
                      .editorChooseAnExternalEuddraftInstallationOrUseTheApp,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _path,
                  enabled: !state.busy,
                  decoration: InputDecoration(
                    labelText: context.l10n.editorExternalEuddraftPath,
                    hintText: r'C:\Tools\euddraft-0.10.2.5',
                    helperText: context
                        .l10n
                        .editorInstallationDirectoryOrEuddraftExeAbsolutePath,
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.controller.directoryPicker != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: state.busy
                          ? null
                          : () async {
                              final selected = await widget.controller
                                  .pickExternalDirectory();
                              if (mounted && selected != null) {
                                _path.text = selected;
                              }
                            },
                      icon: const Icon(Icons.folder_open),
                      label: Text(context.l10n.editorBrowseInstallationFolder),
                    ),
                  ),
                SelectableText(
                  state.path == null
                      ? context.l10n.editorSelectionAppDefault
                      : context.l10n.editorSelectionExternal(
                          (state.path).toString(),
                        ),
                ),
                if (state.path == null && widget.controller.bundledPath == null)
                  Text(context.l10n.editorNoBundledToolIsIncludedInThisAppYet),
                if (state.path == null && widget.controller.bundledPath != null)
                  SelectableText(
                    context.l10n.editorBundledEuddraft01025Editor1No(
                      (widget.controller.bundledPath).toString(),
                    ),
                  ),
                if (state.busy) const LinearProgressIndicator(),
                if (tool != null)
                  SelectableText(
                    context.l10n.editorInspectionPassedEuddraft(
                      (tool.version).toString(),
                      (tool.executablePath).toString(),
                    ),
                  ),
                if (state.error != null)
                  Text(context.localizeEditorText(state.error!)),
                for (final diagnostic in state.result?.diagnostics ?? []) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    '${diagnostic.code}: ${context.diagnosticMessage(diagnostic)}\n${context.diagnosticRemediation(diagnostic) ?? ''}',
                  ),
                  if (diagnostic.rawDetails != null)
                    SelectableText(diagnostic.rawDetails!),
                ],
                const SizedBox(height: 12),
                Text(
                  context
                      .l10n
                      .editorInspectionDoesNotRunTheCompilerSavingThisChoice,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.busy
                ? null
                : () async {
                    await widget.controller.useDefault();
                    if (mounted && widget.controller.state.path == null) {
                      _path.clear();
                    }
                  },
            child: Text(context.l10n.editorUseAppDefault),
          ),
          TextButton(
            onPressed: state.busy ? null : widget.controller.refresh,
            child: Text(context.l10n.editorReinspect),
          ),
          FilledButton(
            onPressed: state.busy
                ? null
                : () => widget.controller.selectExternal(_path.text),
            child: Text(context.l10n.editorSaveAndInspect),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.editorClose),
          ),
        ],
      );
    },
  );
}
