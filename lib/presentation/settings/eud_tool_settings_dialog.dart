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
        title: const Text('EUD Tools'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose an external euddraft installation or use the app default. Project-specific paths take priority.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _path,
                  enabled: !state.busy,
                  decoration: const InputDecoration(
                    labelText: 'External euddraft path',
                    hintText: r'C:\Tools\euddraft-0.10.2.5',
                    helperText:
                        'Installation directory or euddraft.exe (absolute path)',
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
                      label: const Text('Browse installation folder'),
                    ),
                  ),
                SelectableText(
                  state.path == null
                      ? 'Selection: App default'
                      : 'Selection: External\n${state.path}',
                ),
                if (state.path == null && widget.controller.bundledPath == null)
                  const Text(
                    'No bundled tool is included in this app yet. Select an external installation.',
                  ),
                if (state.path == null && widget.controller.bundledPath != null)
                  SelectableText(
                    'Bundled euddraft 0.10.2.5 (editor.1)\n'
                    'No separate Python installation is required. Updates are managed with the app.\n'
                    '${widget.controller.bundledPath}\n'
                    'Licenses and modification details: BUNDLE-NOTICE.txt in this folder.',
                  ),
                if (state.busy) const LinearProgressIndicator(),
                if (tool != null)
                  SelectableText(
                    'Inspection passed — euddraft ${tool.version}\n${tool.executablePath}',
                  ),
                if (state.error != null) Text(state.error!),
                for (final diagnostic in state.result?.diagnostics ?? []) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    '${diagnostic.code}: ${diagnostic.message}\n${diagnostic.remediation ?? ''}',
                  ),
                  if (diagnostic.rawDetails != null)
                    SelectableText(diagnostic.rawDetails!),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Inspection does not run the compiler. Saving this choice does not prepare a build or change an existing build plan.',
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
            child: const Text('Use app default'),
          ),
          TextButton(
            onPressed: state.busy ? null : widget.controller.refresh,
            child: const Text('Reinspect'),
          ),
          FilledButton(
            onPressed: state.busy
                ? null
                : () => widget.controller.selectExternal(_path.text),
            child: const Text('Save and inspect'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
