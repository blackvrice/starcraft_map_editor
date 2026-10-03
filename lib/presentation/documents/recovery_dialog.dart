import 'package:flutter/material.dart';

import '../../application/documents/autosave_controller.dart';
import '../localization/l10n.dart';

class RecoveryDialog extends StatefulWidget {
  const RecoveryDialog({required this.controller, super.key});
  final AutosaveController controller;

  @override
  State<RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<RecoveryDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object {
      if (mounted) {
        _error = widget.controller.lastError == 'RECOVERY_SOURCE_CHANGED'
            ? context.l10n.recoverySourceChanged
            : context.l10n.recoveryFailed;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    return AlertDialog(
      title: Text(l10n.recoveryTitle),
      content: SizedBox(
        width: 680,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Expanded(
              child: controller.candidates.isEmpty
                  ? Center(child: Text(l10n.recoveryEmpty))
                  : ListView.separated(
                      itemCount: controller.candidates.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final entry = controller.candidates[index];
                        final snapshot = entry.snapshot;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot == null
                                  ? l10n.recoveryDamaged
                                  : snapshot.savedAt.toLocal().toString(),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (snapshot != null) ...[
                              if (snapshot.map != null)
                                Text(
                                  l10n.recoveryBaseline(
                                    snapshot.map!.sourcePath ??
                                        l10n.newMapTitle,
                                  ),
                                ),
                              if (snapshot.project != null)
                                Text(
                                  l10n.recoveryProject(
                                    snapshot.projectPath ??
                                        l10n.eudProjectTitle,
                                  ),
                                ),
                              if (snapshot.source != null)
                                Text(
                                  l10n.recoverySource(
                                    snapshot.source!.sourcePath ??
                                        snapshot.source!.fileName,
                                  ),
                                ),
                            ],
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _busy || snapshot == null
                                      ? null
                                      : () => _run(() async {
                                          await controller.restore(entry.id);
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        }),
                                  icon: const Icon(Icons.restore),
                                  label: Text(l10n.recoveryOpen),
                                ),
                                IconButton(
                                  tooltip: l10n.recoveryDelete,
                                  onPressed: _busy
                                      ? null
                                      : () => _run(() async {
                                          final confirmed =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text(
                                                    l10n.recoveryDelete,
                                                  ),
                                                  content: Text(
                                                    l10n.recoveryDeleteConfirm,
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                      child: Text(
                                                        l10n.recoveryCancel,
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      child: Text(
                                                        l10n.recoveryDelete,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                          if (confirmed == true) {
                                            await controller.remove(entry.id);
                                          }
                                        }),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.recoveryClose),
        ),
      ],
    );
  }
}

class AutosaveSettingsDialog extends StatefulWidget {
  const AutosaveSettingsDialog({required this.controller, super.key});
  final AutosaveController controller;
  @override
  State<AutosaveSettingsDialog> createState() => _AutosaveSettingsDialogState();
}

class _AutosaveSettingsDialogState extends State<AutosaveSettingsDialog> {
  late bool _enabled = widget.controller.enabled;
  late double _seconds = widget.controller.interval.inSeconds.toDouble();
  late double _retention = widget.controller.retention.toDouble();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.autosaveSettings),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(l10n.autosaveEnabled),
              value: _enabled,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            Text(l10n.autosaveInterval(_seconds.round())),
            Slider(
              min: 5,
              max: 600,
              divisions: 119,
              value: _seconds,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _seconds = value),
            ),
            Text(l10n.autosaveRetention(_retention.round())),
            Slider(
              min: 1,
              max: 20,
              divisions: 19,
              value: _retention,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _retention = value),
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.recoveryCancel),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.controller.configure(
                      enabled: _enabled,
                      interval: Duration(seconds: _seconds.round()),
                      retention: _retention.round(),
                    );
                    if (context.mounted) Navigator.pop(context);
                  } on Object {
                    if (mounted) {
                      setState(() {
                        _busy = false;
                        _error = l10n.autosaveFailed;
                      });
                    }
                  }
                },
          child: Text(l10n.autosaveApply),
        ),
      ],
    );
  }
}
