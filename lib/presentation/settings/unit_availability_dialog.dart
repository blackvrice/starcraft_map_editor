import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import 'default_unit_names.dart';
import 'default_settings_names.dart';
import 'settings_surface.dart';
import '../../application/editing/settings_id_selection.dart';
import 'settings_selection.dart';
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_unit_availability_editor.dart';

class UnitAvailabilityDialog extends StatefulWidget {
  const UnitAvailabilityDialog({
    required this.controller,
    this.selectedUnit,
    this.onUnitSelected,
    super.key,
  });
  final ObjectEditingController controller;
  final int? selectedUnit;
  final ValueChanged<int>? onUnitSelected;
  @override
  State<UnitAvailabilityDialog> createState() => _UnitAvailabilityDialogState();
}

class _UnitAvailabilityDialogState extends State<UnitAvailabilityDialog> {
  ChkUnitAvailability? _settings;
  RawChkDocument? _snapshot;
  final _draft = <UnitAvailabilityKey, int>{};
  int _player = 0;
  int _unit = 0;
  String? _error;
  final _unitNames = <int, String>{};
  @override
  void initState() {
    super.initState();
    _unit = widget.selectedUnit ?? 0;
    _reload();
  }

  @override
  void didUpdateWidget(UnitAvailabilityDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedUnit != null &&
        oldWidget.selectedUnit != widget.selectedUnit) {
      _unit = widget.selectedUnit!;
    }
  }

  void _selectUnit(int unit) {
    setState(() => _unit = unit);
    widget.onUnitSelected?.call(unit);
  }

  void _reload() {
    _draft.clear();
    _unitNames.clear();
    try {
      final units = widget.controller.unitSettings;
      for (var id = 0; id < 228; id++) {
        try {
          _unitNames[id] = units.name(id);
        } catch (_) {}
      }
    } catch (_) {
      // PUNI remains editable when the independent unit settings are unavailable.
    }
    try {
      _settings = widget.controller.unitAvailability;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _error = null;
    } catch (e) {
      _settings = null;
      _snapshot = null;
      _error = e.toString();
    }
  }

  void _run(VoidCallback action) => setState(() {
    try {
      action();
      _reload();
    } catch (e) {
      _error = e.toString();
    }
  });
  UnitAvailabilityKey _key(ChkUnitAvailabilityField field) =>
      (field == ChkUnitAvailabilityField.global ? null : _player, _unit, field);
  int? _value(ChkUnitAvailabilityField field) =>
      _draft[_key(field)] ?? _settings?.value(_key(field));
  Widget _field(
    ChkUnitAvailabilityField field,
    String label,
    String zero,
    String one,
  ) {
    final key = _key(field);
    final stored = _settings?.value(key);
    final value = _value(field);
    final editable =
        _settings != null &&
        (field == ChkUnitAvailabilityField.global || _player < 8) &&
        (field != ChkUnitAvailabilityField.player ||
            _value(ChkUnitAvailabilityField.inherit) == 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        DropdownButton<int>(
          key: Key('availability-${field.name}'),
          isExpanded: true,
          value: value,
          items: [
            DropdownMenuItem(value: 0, child: Text(zero)),
            DropdownMenuItem(value: 1, child: Text(one)),
            if (stored != null && stored > 1)
              DropdownMenuItem(
                value: stored,
                child: Text(
                  context.l10n.editorStoredIDPreserved((stored).toString()),
                ),
              ),
          ],
          onChanged: editable
              ? (v) => setState(() {
                  if (v == stored) {
                    _draft.remove(key);
                  } else if (v != null) {
                    _draft[key] = v;
                  }
                })
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inherit = _value(ChkUnitAvailabilityField.inherit);
    final effective = inherit == 1
        ? _value(ChkUnitAvailabilityField.global)
        : inherit == 0
        ? _value(ChkUnitAvailabilityField.player)
        : null;
    return SettingsSurface(
      controller: widget.controller,
      snapshot: _snapshot,
      hasDraft: _draft.isNotEmpty,
      onReload: () => setState(_reload),
      title: Text(context.l10n.editorUnitAvailability),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context
                    .l10n
                    .editorMapWideUnitProductionSettingsSeparateFromPlacedUnit,
              ),
              SettingsSelection(
                revision: _snapshot,
                prefix: 'availability',
                selectorKey: const Key('availability-unit'),
                count: 228,
                selected: _unit,
                label: (id) => settingsName(
                  context.l10n.editorUnit,
                  id,
                  defaultUnitNames,
                  custom: _unitNames[id],
                ),
                onSelected: _selectUnit,
                scope: context.l10n
                    .editorMapDefaultsAndPlayerOnlyInheritanceChangesOnlyIf(
                      (_player + 1).toString(),
                    ),
                onCopy: _settings == null
                    ? null
                    : (ids) {
                        final copies = copySettingsDraft(
                          _draft,
                          (key) =>
                              key.$2 == _unit &&
                              (key.$3 == ChkUnitAvailabilityField.global ||
                                  key.$1 == _player),
                          (key, id) => (key.$1, id, key.$3),
                          ids,
                        );
                        setState(() => _draft.addAll(copies));
                        return copies.length;
                      },
              ),
              _field(
                ChkUnitAvailabilityField.global,
                context.l10n.editorMapDefaultAffectsAllInheritingPlayers,
                context.l10n.editorDefaultProhibited,
                context.l10n.editorDefaultAllowed,
              ),
              SettingsSelection(
                prefix: 'availability-players',
                selectorKey: const Key('availability-player-selection'),
                count: 12,
                copyCount: 8,
                idBase: 1,
                selected: _player,
                revision: _snapshot,
                label: (id) => context.l10n.editorPlayer203c6551(
                  (id + 1).toString(),
                  (id >= 8 ? context.l10n.editorReadOnly : "").toString(),
                ),
                onSelected: (id) => setState(() => _player = id),
                scope: context.l10n
                    .editorCopiesOnlyCurrentUnitPlayerEditsToPlayers1(
                      (_unit).toString(),
                    ),
                onCopy: _settings == null || _player >= 8
                    ? null
                    : (ids) {
                        final copies = copySettingsDraft(
                          _draft,
                          (key) => key.$2 == _unit && key.$1 == _player,
                          (key, id) => (id, key.$2, key.$3),
                          ids,
                        );
                        setState(() => _draft.addAll(copies));
                        return copies.length;
                      },
              ),
              _field(
                ChkUnitAvailabilityField.inherit,
                context.l10n.editorPlayerSettingSource,
                context.l10n.editorUsePlayerOverride,
                context.l10n.editorInheritMapDefault,
              ),
              _field(
                ChkUnitAvailabilityField.player,
                context.l10n.editorStoredPlayerOverride,
                context.l10n.editorPlayerProhibited,
                context.l10n.editorPlayerAllowed,
              ),
              Text(
                context.l10n.editorEffectiveAvailability(
                  (effective == 0
                          ? context.l10n.editorProhibited
                          : effective == 1
                          ? context.l10n.editorAllowed
                          : context.l10n.editorUnknownStoredFlagsPreserved)
                      .toString(),
                ),
                key: const Key('availability-effective'),
              ),
              Text(
                context
                    .l10n
                    .editorInheritancePreservesTheStoredOverrideAvailabilityDoesNotBypass,
              ),
              Text(
                context.l10n
                    .editorPendingChangesApplyUpdatesAllEditedUnitsAndPlayers(
                      (_draft.length).toString(),
                    ),
              ),
              if (_error != null)
                Text(
                  context.localizeEditorText(_error!),
                  key: const Key('availability-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('settings-undo'),
          onPressed: widget.controller.canUndo
              ? () => _run(widget.controller.undo)
              : null,
          child: Text(
            context.l10n.editorUndo(
              context.localizeEditorText(widget.controller.undoLabel ?? "—"),
            ),
          ),
        ),
        TextButton(
          key: const Key('settings-redo'),
          onPressed: widget.controller.canRedo
              ? () => _run(widget.controller.redo)
              : null,
          child: Text(
            context.l10n.editorRedo(
              context.localizeEditorText(widget.controller.redoLabel ?? "—"),
            ),
          ),
        ),
        TextButton(
          key: const Key('settings-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.editorCancel),
        ),
        FilledButton(
          key: const Key('availability-apply'),
          onPressed: _snapshot == null || _draft.isEmpty
              ? null
              : () => _run(
                  () => widget.controller.applyUnitAvailability(
                    expectedDocument: _snapshot!,
                    changes: _draft,
                  ),
                ),
          child: Text(context.l10n.editorApply),
        ),
      ],
    );
  }
}
