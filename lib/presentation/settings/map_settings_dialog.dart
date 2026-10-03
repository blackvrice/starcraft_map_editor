import '../localization/l10n.dart';
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../application/placement/placement_catalog_controller.dart';
import 'settings_surface.dart';
import 'map_information_dialog.dart';
import 'player_settings_dialog.dart';
import 'force_settings_dialog.dart';
import 'unit_settings_dialog.dart';
import 'unit_availability_dialog.dart';
import 'upgrade_settings_dialog.dart';
import 'tech_settings_dialog.dart';

class MapSettingsDialog extends StatefulWidget {
  const MapSettingsDialog({
    required this.controller,
    required this.catalogController,
    this.embedded = false,
    this.onClosed,
    this.onExecutionRules,
    super.key,
  });
  final bool embedded;
  final VoidCallback? onClosed;
  final VoidCallback? onExecutionRules;
  final ObjectEditingController controller;
  final PlacementCatalogController catalogController;
  @override
  State<MapSettingsDialog> createState() => _MapSettingsDialogState();
}

class _MapSettingsDialogState extends State<MapSettingsDialog> {
  int _tab = 0;
  int _selectedUnit = 0;
  void _selectUnit(int unit) => setState(() => _selectedUnit = unit);
  int _generation = 0;
  final _visited = <int>{0};
  final _drafts = <int, bool>{};
  bool _closing = false;
  bool _allowClose = false;
  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    if (_drafts.values.any((v) => v)) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.editorDiscardUnappliedSettings),
          content: Text(
            context.l10n.editorOneOrMoreTabsHaveUnappliedDraftsAppliedChanges,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.editorKeepEditing),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.editorDiscardAndClose),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (discard != true) {
        _closing = false;
        return;
      }
    }
    if (widget.embedded) {
      setState(() {
        _generation++;
        _visited.clear();
        _visited.add(0);
        _drafts.clear();
        _tab = 0;
        _selectedUnit = 0;
        _closing = false;
      });
      widget.onClosed?.call();
      return;
    }
    setState(() => _allowClose = true);
    Navigator.of(context).pop();
  }

  Widget _page(int index) => switch (index) {
    0 => MapInformationDialog(controller: widget.controller),
    1 => PlayerSettingsDialog(controller: widget.controller),
    2 => ForceSettingsDialog(controller: widget.controller),
    3 => UnitSettingsDialog(
      selectedUnit: _selectedUnit,
      onUnitSelected: _selectUnit,
      controller: widget.controller,
      catalogController: widget.catalogController,
    ),
    4 => UnitAvailabilityDialog(
      controller: widget.controller,
      selectedUnit: _selectedUnit,
      onUnitSelected: _selectUnit,
    ),
    5 => UpgradeSettingsDialog(controller: widget.controller),
    _ => TechSettingsDialog(controller: widget.controller),
  };
  @override
  Widget build(BuildContext context) => widget.embedded
      ? _content()
      : PopScope(
          canPop: _allowClose,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _close();
          },
          child: Dialog(child: _content()),
        );

  Widget _content() => SizedBox(
    width: 1000,
    height: 780,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.editorMapSettings,
                      style: TextStyle(fontSize: 22),
                    ),
                    Text(
                      context
                          .l10n
                          .editorMapWideSettingsTheCanvasInspectorEditsIndividualPlaced,
                    ),
                  ],
                ),
              ),
              if (widget.onExecutionRules != null)
                TextButton.icon(
                  onPressed: widget.onExecutionRules,
                  icon: const Icon(Icons.bolt),
                  label: Text(context.l10n.editorEUDExecutionRules),
                ),
              TextButton(
                key: const Key('map-settings-close'),
                onPressed: _close,
                child: Text(context.l10n.editorClose),
              ),
            ],
          ),
        ),
        DefaultTabController(
          key: ValueKey(_generation),
          length: 7,
          child: TabBar(
            isScrollable: true,
            onTap: (index) => setState(() {
              _tab = index;
              _visited.add(index);
            }),
            tabs: [
              for (final item in [
                (context.l10n.editorMap, Icons.map_outlined),
                (context.l10n.editorPlayers, Icons.people_outline),
                (context.l10n.editorForces, Icons.flag_outlined),
                (context.l10n.editorUnits, Icons.person_outline),
                (context.l10n.editorAvailability, Icons.checklist),
                (context.l10n.editorUpgrades, Icons.upgrade),
                (context.l10n.editorTech, Icons.science_outlined),
              ])
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.$2, size: 18),
                      const SizedBox(width: 6),
                      Text(item.$1),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              for (var i = 0; i < 7; i++)
                _visited.contains(i)
                    ? SettingsPageScope(
                        key: ValueKey((_generation, i)),
                        reportDraft: (dirty) => _drafts[i] = dirty,
                        child: _page(i),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    ),
  );
}
