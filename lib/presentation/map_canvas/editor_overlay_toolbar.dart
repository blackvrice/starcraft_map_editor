import 'package:flutter/material.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../application/terrain/editor_overlay_controller.dart';
import '../../domain/terrain/terrain_analysis_view.dart';
import '../localization/l10n.dart';

class EditorOverlayToolbar extends StatelessWidget {
  const EditorOverlayToolbar({
    required this.controller,
    required this.layers,
    super.key,
  });
  final EditorOverlayController controller;
  final MapLayerState layers;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = controller;
    final range = c.ranges(layers), field = c.powerField;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 190,
              child: DropdownButton<TerrainAnalysisMode>(
                key: const Key('editor-overlay-mode'),
                value: c.mode,
                isExpanded: true,
                items: [
                  for (final (mode, label) in [
                    (TerrainAnalysisMode.off, l.analysisOff),
                    (TerrainAnalysisMode.elevation, l.analysisElevation),
                    (TerrainAnalysisMode.buildable, l.analysisBuildable),
                    (TerrainAnalysisMode.walkable, l.analysisWalkable),
                    (TerrainAnalysisMode.power, l.analysisPower),
                    (TerrainAnalysisMode.creep, l.analysisCreep),
                  ])
                    DropdownMenuItem(value: mode, child: Text(label)),
                ],
                onChanged: (v) => c.configure(mode: v),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  key: const Key('editor-overlay-ranges'),
                  value: c.showRanges,
                  onChanged: (v) => c.configure(ranges: v),
                ),
                Flexible(child: Text(l.overlayBaseRanges)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  key: const Key('editor-overlay-layout-power'),
                  value: c.showLayoutPower,
                  onChanged: (v) => c.configure(power: v),
                ),
                Flexible(child: Text(l.overlayLayoutPower)),
              ],
            ),
            if (c.showLayoutPower)
              SizedBox(
                width: 100,
                child: DropdownButton<int>(
                  key: const Key('editor-overlay-owner'),
                  value: c.owner,
                  isExpanded: true,
                  items: [
                    for (var i = 0; i < 8; i++)
                      DropdownMenuItem(value: i, child: Text('P${i + 1}')),
                  ],
                  onChanged: (v) => c.configure(owner: v),
                ),
              ),
            IconButton(
              key: const Key('editor-overlay-load'),
              tooltip: l.analysisLoad,
              onPressed: c.loading ? null : c.load,
              icon: c.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
            ),
          ],
        ),
        if (c.showRanges) ...[
          Text(l.overlayBaseOnly),
          Text(
            '${l.overlayRangeLegend} · ${l.analysisUnknown}: '
            '${range.unknownUnits}',
          ),
          if (range.selectionLimitExceeded) Text(l.overlayBudget),
          if (c.catalog.inspectionDatSource case final source?)
            Text(source.label),
        ],
        if (c.showLayoutPower) ...[
          Text(l.overlayLayoutOnly),
          Text(
            field == null || field.failure != null
                ? '${l.analysisUnknown}: ${field?.failure?.name ?? "DATA_OR_BUDGET"}'
                : '${l.overlayProviders}: ${field.providers.length}',
          ),
          if (c.catalog.inspectionUnitIdentity case final source?)
            Text('${source.$1} / ${source.$2}; helper ${source.$3}'),
        ],
        if (c.mode == TerrainAnalysisMode.power ||
            c.mode == TerrainAnalysisMode.creep)
          Text(l.analysisRuntimeUnsupported)
        else if (c.mode != TerrainAnalysisMode.off) ...[
          Text(
            c.catalog.inspectionTerrainSource == null
                ? l.analysisUnknown
                : l.analysisStaticOnly,
          ),
          if (c.catalog.inspectionTerrainSource case final source?)
            Text(
              '${source.storageProduct} / ${source.storageBuildNumber}; '
              'helper ${source.helperVersion}; ${source.revision}',
            ),
        ],
        if (c.error case final error?) Text(error),
      ],
    );
  }
}
