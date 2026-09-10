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
    super.key,
  });
  final ObjectEditingController controller;
  final PlacementCatalogController catalogController;
  @override
  State<MapSettingsDialog> createState() => _MapSettingsDialogState();
}

class _MapSettingsDialogState extends State<MapSettingsDialog> {
  int _tab = 0;
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
          title: const Text('Discard unapplied settings?'),
          content: const Text(
            'One or more tabs have unapplied drafts. Applied changes remain in the map and can be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard and close'),
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
    setState(() => _allowClose = true);
    Navigator.of(context).pop();
  }

  Widget _page(int index) => switch (index) {
    0 => MapInformationDialog(controller: widget.controller),
    1 => PlayerSettingsDialog(controller: widget.controller),
    2 => ForceSettingsDialog(controller: widget.controller),
    3 => UnitSettingsDialog(
      controller: widget.controller,
      catalogController: widget.catalogController,
    ),
    4 => UnitAvailabilityDialog(controller: widget.controller),
    5 => UpgradeSettingsDialog(controller: widget.controller),
    _ => TechSettingsDialog(controller: widget.controller),
  };
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowClose,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Dialog(
      child: SizedBox(
        width: 1000,
        height: 780,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Map Settings', style: TextStyle(fontSize: 22)),
                        Text(
                          'Map-wide settings. The canvas Inspector edits individual placed objects. Apply affects the current tab; Save As writes the map.',
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('map-settings-close'),
                    onPressed: _close,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            DefaultTabController(
              length: 7,
              child: TabBar(
                isScrollable: true,
                onTap: (index) => setState(() {
                  _tab = index;
                  _visited.add(index);
                }),
                tabs: [
                  for (final name in [
                    'Map',
                    'Players',
                    'Forces',
                    'Units',
                    'Availability',
                    'Upgrades',
                    'Tech',
                  ])
                    Tab(text: name),
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
                            key: ValueKey(i),
                            reportDraft: (dirty) => _drafts[i] = dirty,
                            child: _page(i),
                          )
                        : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
