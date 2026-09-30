import 'package:flutter/material.dart';
import '../../domain/chk/typed/chk_editor_terrain.dart';
import '../localization/l10n.dart';

class TerrainDataPanel extends StatelessWidget {
  const TerrainDataPanel({required this.report, super.key});
  final ChkEditorTerrainReport report;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        key: const Key('terrain-data-panel'),
        tilePadding: EdgeInsets.zero,
        title: Text(l.terrainDataTitle),
        subtitle: Text(
          report.hasProtectionMarker
              ? l.terrainDataProtected
              : report.hasIsom
              ? l.terrainDataIsomPresent
              : l.terrainDataNoIsom,
        ),
        children: [
          for (final s in report.sections)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${s.rawSection.name} · #${s.sectionIndex}'),
              subtitle: Text(
                '${l.terrainDataBytes(s.rawSection.payload.length, s.expectedBytes?.toString() ?? "?")}\n${switch (s.state) {
                  EditorTerrainSectionState.validStructure => l.terrainDataStructureOnly,
                  EditorTerrainSectionState.invalidSize => l.terrainDataInvalidSize,
                  EditorTerrainSectionState.unknownDimensions => l.terrainDataUnknownDimensions,
                  EditorTerrainSectionState.protectionMarker => l.terrainDataProtected,
                }}',
              ),
            ),
          if (report.duplicateNames.isNotEmpty)
            Text(l.terrainDataDuplicates(report.duplicateNames.join(', '))),
          Text(
            report.differentTileCount == null
                ? l.terrainDataComparisonUnavailable
                : l.terrainDataDifference(report.differentTileCount!),
          ),
          if (report.hasDoodads) Text(l.terrainDataDoodads),
          const SizedBox(height: 8),
          Text(l.terrainDataReadOnly),
        ],
      ),
    );
  }
}
