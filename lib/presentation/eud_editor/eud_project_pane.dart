import 'package:flutter/material.dart';
import 'dart:ui' show AppExitResponse;
import '../../application/eud/eud_project_workspace.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../localization/l10n.dart';
import 'eud_field_labels.dart';
import 'eud_impact_pane.dart';
import 'eud_weapon_editor.dart';
import 'eud_shield_editor.dart';
import 'eud_field_editor.dart';
import 'eud_rules_editor.dart';
import '../../domain/eud/eud_field_manifest.dart';
import '../../domain/eud/eud_effective_settings.dart';
import '../../domain/eud/eud_generated_settings.dart';
import '../../domain/eud/eud_project.dart';

const _eudAccent = Color(0xFFE3A64A);
const _cardColor = Color(0xFF1B1F24);
const _cardBorder = Color(0xFF2C3238);
const _muted = Color(0xFFA7AFB8);
const _good = Color(0xFF6CC48A);
const _warn = Color(0xFFF0C982);

/// The EUD extension workspace: what changed, where it is stored and what is
/// still needed before the values reach the game.
///
/// Every action goes through [EudProjectWorkspace]; this widget never reads
/// or writes files itself.
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
  int _linkedWeapon = 0;
  int _linkRevision = 0;
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
          builder: (context) {
            final l10n = context.l10n;
            return AlertDialog(
              title: Text(l10n.eudDiscardTitle),
              content: Text(l10n.eudDiscardBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.eudCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.eudDiscard),
                ),
              ],
            );
          },
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

  Future<void> _showPreview(EudProject project) async {
    final preview = EudGeneratedSettings(project);
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.eudGenerationPreviewTitle),
          content: SizedBox(
            width: 720,
            height: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.eudGenerationPreviewNote),
                  const SizedBox(height: 12),
                  SelectableText(
                    preview.manifest,
                    key: const Key('eud-generation-manifest'),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    preview.source,
                    key: const Key('eud-generated-source'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.eudClose),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: widget.workspace.changes,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final workspace = widget.workspace;
        final project = workspace.projects.project;
        final busy = workspace.isBusy || _acting;
        final wide = constraints.maxWidth >= 1000;
        final header = _header(context, busy);
        if (project == null) {
          return Material(
            color: const Color(0xFF14171B),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                header,
                const SizedBox(height: 16),
                ..._notices(context),
                _welcome(context, busy),
              ],
            ),
          );
        }
        final main = <Widget>[
          ..._notices(context),
          _changes(context, project, busy),
          const SizedBox(height: 16),
          _Card(
            child: EudRulesEditor(
              controller: workspace.projects,
              enabled: !busy,
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: EudWeaponEditor(
              key: ValueKey(('linked-weapon', _linkRevision)),
              selectedWeapon: _linkedWeapon,
              controller: workspace.projects,
              enabled: !busy,
              onEditingChanged: (editing) => setState(() => _acting = editing),
            ),
          ),
          const SizedBox(height: 16),
          _Card(child: _impact(context, project, busy)),
        ];
        final side = <Widget>[
          _steps(context, project, busy),
          const SizedBox(height: 16),
          _connection(context, project, busy),
        ];
        return Material(
          color: const Color(0xFF14171B),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              header,
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: main,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 330,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: side,
                      ),
                    ),
                  ],
                )
              else ...[
                ...side,
                const SizedBox(height: 16),
                ...main,
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _header(BuildContext context, bool busy) {
    final l10n = context.l10n;
    final workspace = widget.workspace;
    final controller = workspace.projects;
    final project = controller.project;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2418),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.code_rounded, color: _eudAccent),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '${l10n.eudProjectTitle}${controller.isDirty ? l10n.eudProjectUnsavedSuffix : ''}',
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            if (project != null)
              _Pill(
                text: l10n.eudRuntimeUnverified,
                color: _warn,
                background: const Color(0xFF332C16),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.eudProjectLead,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (project == null)
              FilledButton.icon(
                key: const Key('eud-project-new'),
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: busy ? null : _createFromMap,
                label: Text(l10n.eudNewFromMap),
              )
            else
              OutlinedButton(
                key: const Key('eud-project-new'),
                onPressed: busy ? null : _createFromMap,
                child: Text(l10n.eudNewFromMap),
              ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      if (await _discard()) {
                        await workspace.open(discardChanges: true);
                      }
                    }),
              child: Text(l10n.eudOpenProject),
            ),
            if (project != null) ...[
              OutlinedButton(
                onPressed: busy || !controller.canSave
                    ? null
                    : () => _run(workspace.save),
                child: Text(l10n.eudSaveProject),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => _run(workspace.saveAs),
                child: Text(l10n.eudSaveProjectAs),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                icon: const Icon(Icons.undo_rounded, size: 18),
                onPressed: busy || !controller.canUndo ? null : controller.undo,
                label: Text(l10n.eudUndoProject),
              ),
              TextButton.icon(
                icon: const Icon(Icons.redo_rounded, size: 18),
                onPressed: busy || !controller.canRedo ? null : controller.redo,
                label: Text(l10n.eudRedoProject),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => _run(() async {
                        if (await _discard()) {
                          controller.close(discardChanges: true);
                        }
                      }),
                child: Text(l10n.eudCloseProject),
              ),
            ],
          ],
        ),
        if (workspace.isBusy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  void _createFromMap() => _run(() async {
    if (await _discard()) {
      await widget.workspace.createFromMap(discardChanges: true);
    }
  });

  List<Widget> _notices(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.workspace.projects;
    final project = controller.project;
    final errorColor = Theme.of(context).colorScheme.error;
    final problems = <Widget>[
      if (_error != null)
        SelectableText(_error!, style: TextStyle(color: errorColor)),
      if (project != null)
        for (final issue in project.validationIssues)
          Text(issue, style: TextStyle(color: errorColor)),
      if (controller.saveWarning != null)
        SelectableText(controller.saveWarning!),
    ];
    return [
      if (problems.isNotEmpty) ...[
        _Card(
          border: const Color(0xFF5A3A3E),
          color: const Color(0xFF221719),
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFEF8A91),
          title: l10n.eudProblems,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: problems,
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  Widget _welcome(BuildContext context, bool busy) {
    final l10n = context.l10n;
    Widget point(int number, IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFF2A2418),
            child: Text(
              '$number',
              style: const TextStyle(fontSize: 12, color: _eudAccent),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: _muted),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return _Card(
      icon: Icons.lightbulb_outline_rounded,
      iconColor: _eudAccent,
      title: l10n.eudWelcomeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          point(1, Icons.tune_rounded, l10n.eudWelcomeChoose),
          point(2, Icons.save_outlined, l10n.eudWelcomeSave),
          point(3, Icons.play_arrow_rounded, l10n.eudWelcomeBuild),
          const SizedBox(height: 6),
          Text(
            _bindingMessage(context, widget.workspace.binding),
            key: const Key('eud-project-binding'),
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.eudProjectSaveNote,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _changes(BuildContext context, EudProject project, bool busy) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final controller = widget.workspace.projects;
    final effective = widget.workspace.effectiveSettings;
    final rows = <Widget>[];
    for (var i = 0; i < project.overrides.length; i++) {
      final item = project.overrides[i];
      final setting = i < effective.length ? effective[i] : null;
      rows.add(
        Container(
          key: ValueKey(('eud-override', i)),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF16191D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: 10),
                decoration: const BoxDecoration(
                  color: _eudAccent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          EudFieldLabels.label(locale, item.field),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        _Pill(
                          text: EudFieldLabels.group(locale, item.field),
                          color: const Color(0xFFC9CFD6),
                          background: const Color(0xFF23272C),
                        ),
                        if (item.overrideChk)
                          _Pill(
                            text: l10n.eudExplicitChk,
                            color: const Color(0xFFECD08A),
                            background: const Color(0xFF332C16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.field} — ${_targetName(item.field, item.targetId)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (setting != null)
                      Text(
                        l10n.eudBaselineLine(_baseline(context, setting)),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    Text(
                      l10n.eudPlannedLine(
                        '${item.value}',
                        setting == null
                            ? l10n.eudUnresolved
                            : '${setting.plannedValue ?? l10n.eudUnresolved}',
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: ValueKey(('eud-override-revert', i)),
                onPressed: busy
                    ? null
                    : () => _run(() async {
                        final current = controller.project;
                        if (current == null) return;
                        controller.replaceOverrides(
                          current.overrides.where(
                            (other) => other.identity != item.identity,
                          ),
                        );
                      }),
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: Text(l10n.eudRevert),
              ),
            ],
          ),
        ),
      );
    }
    return _Card(
      icon: Icons.tune_rounded,
      iconColor: _eudAccent,
      title: l10n.eudChangesTitle,
      trailing: OutlinedButton.icon(
        key: const Key('eud-all-fields'),
        icon: const Icon(Icons.tune),
        onPressed: busy
            ? null
            : () => _run(
                () => showEudFieldEditor(context, controller: controller),
              ),
        label: Text(l10n.eudAllFields),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.eudChangesCount(project.overrides.length),
            style: const TextStyle(color: _muted, fontSize: 12.5),
          ),
          if (project.overrides.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l10n.eudChangesEmpty),
            )
          else ...[
            const SizedBox(height: 4),
            Text(
              l10n.eudPreviewOnlyNote,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            ...rows,
          ],
          const SizedBox(height: 10),
          Text(
            l10n.eudAllFieldsNote,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _impact(BuildContext context, EudProject project, bool busy) {
    final controller = widget.workspace.projects;
    return EudImpactPane(
      onSelectWeapon: busy
          ? null
          : (weapon) => setState(() {
              _linkedWeapon = weapon;
              _linkRevision++;
            }),
      key: const ValueKey('eud-project-impact'),
      project: project,
      catalog: widget.catalog,
      onEditShields: busy
          ? null
          : (unit) => _run(
              () => showEudShieldEditor(
                context,
                controller: controller,
                unit: unit,
              ),
            ),
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
    );
  }

  Widget _steps(BuildContext context, EudProject project, bool busy) {
    final l10n = context.l10n;
    final workspace = widget.workspace;
    final controller = workspace.projects;
    final count = project.overrides.length + project.rules.length;
    final saved = controller.path != null && !controller.isDirty;
    final matched = workspace.binding == EudMapBinding.matched;
    return _Card(
      key: const Key('eud-project-steps'),
      icon: Icons.flag_outlined,
      iconColor: _eudAccent,
      title: l10n.eudStepsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepRow(
            number: 1,
            title: l10n.eudStepChoose,
            subtitle: count == 0
                ? l10n.eudStepChooseNone
                : l10n.eudStepChooseDone(count),
            done: count > 0,
          ),
          _StepRow(
            number: 2,
            title: l10n.eudStepSave,
            subtitle: saved ? l10n.eudStepSaveDone : l10n.eudStepSaveNeeded,
            done: saved,
          ),
          _StepRow(
            number: 3,
            title: l10n.eudStepVerify,
            subtitle: _bindingMessage(context, workspace.binding),
            done: matched,
          ),
          _StepRow(
            number: 4,
            title: l10n.eudStepBuild,
            subtitle: workspace.hasUnbuiltOverrides
                ? l10n.eudStepBuildHint
                : l10n.eudStepBuildIdle,
            done: false,
            last: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('eud-generation-preview'),
              icon: const Icon(Icons.code_rounded, size: 18),
              onPressed: busy ? null : () => _run(() => _showPreview(project)),
              label: Text(l10n.eudGenerationPreview),
            ),
          ),
          if (controller.backupPath != null)
            SelectableText(
              l10n.eudRecoveryBackup(controller.backupPath!),
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
        ],
      ),
    );
  }

  Widget _connection(BuildContext context, EudProject project, bool busy) {
    final l10n = context.l10n;
    final workspace = widget.workspace;
    final binding = workspace.binding;
    final (icon, color) = switch (binding) {
      EudMapBinding.matched => (Icons.link_rounded, _good),
      EudMapBinding.unchecked => (Icons.help_outline_rounded, _warn),
      EudMapBinding.noMap ||
      EudMapBinding.unsavedMap => (Icons.info_outline_rounded, _warn),
      _ => (Icons.link_off_rounded, const Color(0xFFEF8A91)),
    };
    return _Card(
      icon: Icons.map_outlined,
      iconColor: _muted,
      title: l10n.eudConnectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _bindingMessage(context, binding),
                  key: const Key('eud-project-binding'),
                  style: TextStyle(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy ? null : () => _run(workspace.verify),
                child: Text(l10n.eudVerifyMap),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => _run(workspace.rebind),
                child: Text(l10n.eudConnectMap),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.eudTechnical,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 4),
          SelectableText(
            l10n.eudProjectInfo(
              workspace.projects.path ?? l10n.eudNotSaved,
              project.mapPath,
              project.mapSha256,
            ),
            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.eudProjectSaveNote,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _bindingMessage(BuildContext context, EudMapBinding binding) {
    final l10n = context.l10n;
    return switch (binding) {
      EudMapBinding.unchecked => l10n.eudBindingUnchecked,
      EudMapBinding.noMap => l10n.eudBindingNoMap,
      EudMapBinding.unsavedMap => l10n.eudBindingUnsaved,
      EudMapBinding.restrictedMap => l10n.eudBindingRestricted,
      EudMapBinding.matched => l10n.eudBindingMatched,
      EudMapBinding.mismatch => l10n.eudBindingMismatch,
      EudMapBinding.diskChanged => l10n.eudBindingDiskChanged,
    };
  }

  String _targetName(String field, int id) {
    final table = EudFieldManifest.find(field)?.table;
    return table == null ? '#$id' : eudTargetName(table, id);
  }

  String _baseline(BuildContext context, EudEffectiveSetting setting) {
    final l10n = context.l10n;
    final detail = setting.baselineDetail ?? '';
    return switch (setting.baselineSource) {
      EudBaselineSource.unverifiedMap => l10n.eudBaselineUnverified,
      EudBaselineSource.chk => '${setting.baselineValue} ($detail)',
      EudBaselineSource.gameDefault => l10n.eudBaselineGameDefault(detail),
      EudBaselineSource.unavailable => l10n.eudBaselineUnavailable(detail),
      EudBaselineSource.notInChk => l10n.eudBaselineNotInChk(detail),
    };
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.color = _cardColor,
    this.border = _cardBorder,
    super.key,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: TextStyle(fontSize: 11.5, color: color)),
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.done,
    this.last = false,
  });

  final int number;
  final String title;
  final String subtitle;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? const Color(0xFF16231A) : Colors.transparent,
            border: Border.all(
              color: done ? const Color(0xFF2F4A36) : const Color(0xFF3A4048),
              width: 1.5,
            ),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: _good)
              : Text(
                  '$number',
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
