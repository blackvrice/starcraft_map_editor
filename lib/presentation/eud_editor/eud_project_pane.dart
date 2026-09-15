import 'package:flutter/material.dart';
import 'dart:ui' show AppExitResponse;
import '../../application/eud/eud_project_workspace.dart';
import '../../application/placement/placement_catalog_controller.dart';
import 'eud_impact_pane.dart';
import 'eud_weapon_editor.dart';
import '../../domain/eud/eud_effective_settings.dart';
import '../settings/default_unit_names.dart';
import '../settings/default_settings_names.dart';

class EudProjectPane extends StatefulWidget {
  const EudProjectPane({required this.workspace, this.catalog, super.key});
  final EudProjectWorkspace workspace;
  final PlacementCatalogController? catalog;
  @override
  State<EudProjectPane> createState() => _EudProjectPaneState();
}

class _EudProjectPaneState extends State<EudProjectPane> {
  String? _error;
  bool _acting = false;
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        if (widget.workspace.isBusy || _acting) return AppExitResponse.cancel;
        return await _discard() ? AppExitResponse.exit : AppExitResponse.cancel;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<bool> _discard() async {
    if (!widget.workspace.projects.isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard EUD project changes?'),
            content: const Text(
              'The EUD project has unsaved changes. Save Project As before continuing to keep them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_acting) return;
    setState(() {
      _error = null;
      _acting = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: widget.workspace.changes,
    builder: (context, _) {
      final workspace = widget.workspace;
      final controller = workspace.projects;
      final project = controller.project;
      final busy = workspace.isBusy || _acting;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'EUD Project${controller.isDirty ? ' • Unsaved' : ''}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('eud-project-new'),
                onPressed: busy
                    ? null
                    : () => _run(() async {
                        if (await _discard()) {
                          await workspace.createFromMap(discardChanges: true);
                        }
                      }),
                child: const Text('New from current map'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _run(() async {
                        if (await _discard()) {
                          await workspace.open(discardChanges: true);
                        }
                      }),
                child: const Text('Open Project'),
              ),
              OutlinedButton(
                onPressed: busy || !controller.canSave
                    ? null
                    : () => _run(workspace.save),
                child: const Text('Save Project'),
              ),
              OutlinedButton(
                onPressed: busy || project == null
                    ? null
                    : () => _run(workspace.saveAs),
                child: const Text('Save Project As'),
              ),
              TextButton(
                onPressed: busy || !controller.canUndo ? null : controller.undo,
                child: const Text('Undo project'),
              ),
              TextButton(
                onPressed: busy || !controller.canRedo ? null : controller.redo,
                child: const Text('Redo project'),
              ),
              TextButton(
                onPressed: busy || project == null
                    ? null
                    : () => _run(() async {
                        if (await _discard()) {
                          controller.close(discardChanges: true);
                        }
                      }),
                child: const Text('Close Project'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Project saving preserves EUD settings; it does not compile a map. Map Save As saves ordinary map changes.',
          ),
          const Text(
            'Weapon EUD settings can be edited below. Generated builds are not connected yet. Save Project checks for external changes and keeps a recovery backup.',
          ),
          if (workspace.isBusy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectableText(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _bindingMessage(workspace.binding),
            key: const Key('eud-project-binding'),
          ),
          if (project != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Project: ${controller.path ?? 'Not saved'}\nMap: ${project.mapPath}\nSHA-256: ${project.mapSha256}',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => _run(workspace.verify),
                  child: const Text('Verify current map'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => _run(workspace.rebind),
                  child: const Text('Connect current map'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            EudWeaponEditor(
              controller: controller,
              enabled: !busy,
              onEditingChanged: (editing) => setState(() => _acting = editing),
            ),
            Text(
              '${project.overrides.length} stored overrides • Runtime unverified',
            ),
            if (workspace.hasUnbuiltOverrides)
              const Text(
                'EUD Build is disabled while this project has overrides: generated project builds are not connected yet.',
              ),
            if (controller.backupPath != null)
              SelectableText('Recovery backup: ${controller.backupPath}'),
            if (controller.saveWarning != null)
              SelectableText(controller.saveWarning!),
            for (final issue in project.validationIssues)
              Text(
                issue,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (project.overrides.isNotEmpty) ...[
              const Text('CHK baseline / planned EUD values'),
              const Text(
                'Preview only, not applied in game. Verify current map after changes. Project validation errors block all planned values.',
              ),
              for (final setting in workspace.effectiveSettings)
                Text(
                  '${setting.override.identity} — Baseline: ${_baseline(setting)}\n'
                  'Requested EUD: ${setting.override.value} • Planned EUD value: ${setting.plannedValue ?? 'Unresolved'}',
                ),
            ],
            for (final item in project.overrides)
              ListTile(
                dense: true,
                title: Text(
                  '${item.field} — ${_targetName(item.field, item.targetId)}',
                ),
                subtitle: Text(
                  '${item.value}${item.overrideChk ? ' • Explicit CHK override' : ''}',
                ),
              ),
            EudImpactPane(
              key: const ValueKey('eud-project-impact'),
              project: project,
              catalog: widget.catalog,
              onEditWeapon: busy
                  ? null
                  : (weapon, epoch) {
                      final catalog = widget.catalog;
                      _run(
                        () => showEudWeaponEditor(
                          context,
                          controller: controller,
                          weapon: weapon,
                          referenceIsCurrent: () =>
                              identical(catalog, widget.catalog) &&
                              catalog?.weaponReferenceEpoch == epoch,
                        ),
                      );
                    },
            ),
          ],
        ],
      );
    },
  );

  String _bindingMessage(EudMapBinding binding) => switch (binding) {
    EudMapBinding.unchecked =>
      'Map connection has not been verified. Use Verify current map.',
    EudMapBinding.noMap => 'Open a map to connect an EUD project.',
    EudMapBinding.unsavedMap =>
      'The map has unsaved changes. Save the map before connecting.',
    EudMapBinding.restrictedMap =>
      'This map is restricted and cannot be connected for editing.',
    EudMapBinding.matched =>
      'Current map matches the project (verified snapshot).',
    EudMapBinding.mismatch =>
      'Current map differs from the project. Open the linked map or explicitly connect this map.',
    EudMapBinding.diskChanged =>
      'The map changed on disk. Reopen it before connecting.',
  };

  String _targetName(String field, int id) {
    final names = field.startsWith('unit.')
        ? defaultUnitNames
        : field.startsWith('weapon.')
        ? defaultWeaponNames
        : const <String>[];
    final name = id >= 0 && id < names.length ? names[id] : '';
    return name.isEmpty ? '#$id' : '$name (#$id)';
  }

  String _baseline(EudEffectiveSetting setting) =>
      switch (setting.baselineSource) {
        EudBaselineSource.unverifiedMap => 'Unverified map',
        EudBaselineSource.chk =>
          '${setting.baselineValue} (${setting.baselineDetail})',
        EudBaselineSource.gameDefault =>
          'Game default (unknown; ${setting.baselineDetail})',
        EudBaselineSource.unavailable =>
          'Unavailable (${setting.baselineDetail})',
        EudBaselineSource.notInChk =>
          'Not stored in CHK; ${setting.baselineDetail}',
      };
}
