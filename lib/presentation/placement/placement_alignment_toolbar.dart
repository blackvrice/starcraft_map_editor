import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/placement/placement_catalog_controller.dart';
import '../../domain/placement/point_placement_snap.dart';
import '../../domain/placement/unit_placement_policy.dart';
import '../localization/l10n.dart';
import 'placement_policy_dialog.dart';

class PlacementAlignmentToolbar extends StatelessWidget {
  const PlacementAlignmentToolbar({required this.controller, super.key});

  final PlacementCatalogController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = controller.state;
    final snap = state.pointSnap;
    final mode = state.unitPlacementPolicy.mode;
    return Wrap(
      key: const Key('placement-alignment-toolbar'),
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${l10n.placementUnitPolicy}: ${switch (mode) {
                      UnitPlacementMode.checked => l10n.placementPolicyChecked,
                      UnitPlacementMode.free => l10n.placementPolicyFree,
                      UnitPlacementMode.custom => l10n.placementPolicyCustom,
                    }}',
                    key: const Key('placement-policy-mode'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              SizedBox(
                width: 226,
                height: 40,
                child: SegmentedButton<UnitPlacementMode>(
                  key: const Key('placement-policy-presets'),
                  emptySelectionAllowed: true,
                  selected: {if (mode != UnitPlacementMode.custom) mode},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) return;
                    controller.setUnitPlacementPolicy(
                      selection.single == UnitPlacementMode.checked
                          ? UnitPlacementPolicy.checked
                          : UnitPlacementPolicy.free,
                    );
                  },
                  segments: [
                    ButtonSegment(
                      value: UnitPlacementMode.checked,
                      label: Text(l10n.placementPolicyChecked),
                      icon: const Icon(Icons.fact_check_outlined),
                    ),
                    ButtonSegment(
                      value: UnitPlacementMode.free,
                      label: Text(l10n.placementPolicyFree),
                      icon: const Icon(Icons.open_with),
                    ),
                  ],
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              IconButton(
                key: const Key('placement-policy-support'),
                tooltip: l10n.placementPolicySupport,
                icon: const Icon(Icons.rule),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PlacementPolicyDialog(controller: controller),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 260,
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: const Key('placement-check-unit-terrain'),
              value: state.checkUnitTerrain,
              onChanged: (value) => controller.setCheckUnitTerrain(value!),
              title: Text(l10n.placementCheckUnitTerrain),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: !state.checkUnitTerrain
                  ? null
                  : SizedBox(
                      width: 40,
                      height: 40,
                      child: state.isTerrainPlacementLoading
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const Key('placement-reload-unit-terrain'),
                              tooltip: l10n.placementReloadUnitTerrain,
                              icon: const Icon(Icons.refresh),
                              onPressed: () =>
                                  controller.loadTerrainPlacement(reload: true),
                            ),
                    ),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: const Key('placement-allow-unit-overlap'),
              value: state.allowUnitOverlap,
              onChanged: (value) => controller.setAllowUnitOverlap(value!),
              title: Text(l10n.placementAllowUnitOverlap),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: state.allowUnitOverlap
                  ? null
                  : SizedBox(
                      width: 40,
                      height: 40,
                      child: state.isCollisionMetadataLoading
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const Key('placement-reload-collision'),
                              tooltip: l10n.placementReloadCollisionMetadata,
                              icon: const Icon(Icons.refresh),
                              onPressed: () => controller.loadCollisionMetadata(
                                reload: true,
                              ),
                            ),
                    ),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: const Key('placement-check-resource-distance'),
              value: state.checkResourceDistance,
              onChanged: (value) => controller.setCheckResourceDistance(value!),
              title: Text(l10n.placementCheckResourceDistance),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: !state.checkResourceDistance
                  ? null
                  : SizedBox(
                      width: 40,
                      height: 40,
                      child: state.isCollisionMetadataLoading
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const Key(
                                'placement-reload-resource-distance',
                              ),
                              tooltip: l10n.placementReloadResourceDistance,
                              icon: const Icon(Icons.refresh),
                              onPressed: () => controller.loadCollisionMetadata(
                                reload: true,
                              ),
                            ),
                    ),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: const Key('placement-check-preplaced-power'),
              value: state.checkPreplacedPower,
              onChanged: (value) => controller.setCheckPreplacedPower(value!),
              title: Text(l10n.placementCheckPreplacedPower),
              subtitle: Text(l10n.placementPreplacedPowerScope),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: !state.checkPreplacedPower
                  ? null
                  : SizedBox(
                      width: 40,
                      height: 40,
                      child: state.isCollisionMetadataLoading
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const Key(
                                'placement-reload-preplaced-power',
                              ),
                              tooltip: l10n.placementReloadPreplacedPower,
                              icon: const Icon(Icons.refresh),
                              onPressed: () => controller.loadCollisionMetadata(
                                reload: true,
                              ),
                            ),
                    ),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: const Key('placement-building-tile-alignment'),
              value: state.alignBuildingsToTiles,
              onChanged: (value) => controller.setBuildingTileAlignment(value!),
              title: Text(l10n.placementBuildingTileAlignment),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Checkbox(
              key: const Key('placement-grid-visible'),
              value: state.gridVisible,
              onChanged: (value) => controller.setGridVisible(value!),
              semanticLabel: l10n.placementGrid,
            ),
            Text(l10n.placementGrid),
            const SizedBox(width: 8),
            SizedBox(
              width: 112,
              child: DropdownButton<int>(
                key: const Key('placement-grid-spacing'),
                isExpanded: true,
                value: state.gridSpacingPixels ?? 0,
                items: [
                  DropdownMenuItem(
                    value: 0,
                    child: Text(l10n.placementGridAuto),
                  ),
                  for (final step in PointPlacementSnap.presets)
                    DropdownMenuItem(value: step, child: Text('$step px')),
                ],
                onChanged: state.gridVisible
                    ? (value) =>
                          controller.setGridSpacing(value == 0 ? null : value)
                    : null,
              ),
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Checkbox(
              key: const Key('placement-point-snap'),
              value: snap.enabled,
              onChanged: (value) =>
                  controller.setPointSnap(enabled: value!, step: snap.step),
              semanticLabel: l10n.placementPointSnap,
            ),
            Text(l10n.placementPointSnap),
            const SizedBox(width: 8),
            SizedBox(
              width: 112,
              child: DropdownButton<int>(
                key: const Key('placement-snap-spacing'),
                isExpanded: true,
                value: snap.step,
                items: [
                  for (final step in {
                    ...PointPlacementSnap.presets,
                    snap.step,
                  }.toList()..sort())
                    DropdownMenuItem(value: step, child: Text('$step px')),
                  DropdownMenuItem(
                    value: 0,
                    child: Text(l10n.placementCustomSnap, maxLines: 2),
                  ),
                ],
                onChanged: snap.enabled
                    ? (value) async {
                        final step = value == 0
                            ? await _customStep(context, snap.step)
                            : value;
                        if (step != null && context.mounted) {
                          controller.setPointSnap(enabled: true, step: step);
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<int?> _customStep(BuildContext context, int current) async {
    final l10n = context.l10n;
    final form = GlobalKey<FormState>();
    var step = current;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.placementCustomSnap),
        content: SizedBox(
          width: 240,
          child: Form(
            key: form,
            child: TextFormField(
              key: const Key('placement-custom-snap-input'),
              initialValue: '$current',
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(suffixText: 'px'),
              validator: (value) {
                final number = int.tryParse(value ?? '');
                if (number == null ||
                    number < 1 ||
                    number > PointPlacementSnap.maximumStep) {
                  return l10n.placementSnapRange;
                }
                step = number;
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.editorCancel),
          ),
          FilledButton(
            key: const Key('placement-custom-snap-apply'),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, step);
            },
            child: Text(l10n.editorApply),
          ),
        ],
      ),
    );
  }
}
