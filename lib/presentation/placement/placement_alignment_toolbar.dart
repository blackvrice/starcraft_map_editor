import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/placement/placement_catalog_controller.dart';
import '../../domain/placement/point_placement_snap.dart';
import '../localization/l10n.dart';

class PlacementAlignmentToolbar extends StatelessWidget {
  const PlacementAlignmentToolbar({required this.controller, super.key});

  final PlacementCatalogController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = controller.state;
    final snap = state.pointSnap;
    return Wrap(
      key: const Key('placement-alignment-toolbar'),
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
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
