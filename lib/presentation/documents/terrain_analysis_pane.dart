import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/documents/isom_fill_controller.dart';
import '../../application/editing/basic_editing_controller.dart';
import '../../application/terrain/terrain_analysis_controller.dart';
import '../../domain/terrain/terrain_analysis_view.dart';
import '../localization/l10n.dart';
import '../map_canvas/map_canvas.dart';
import '../map_canvas/terrain_tile_texture_controller.dart';

class TerrainAnalysisPane extends StatefulWidget {
  const TerrainAnalysisPane({
    required this.editing,
    this.loader,
    this.textures = const TerrainTileTextureState.idle(),
    super.key,
  });
  final BasicEditingController editing;
  final IsomFillController? loader;
  final TerrainTileTextureState textures;
  @override
  State<TerrainAnalysisPane> createState() => _TerrainAnalysisPaneState();
}

class _TerrainAnalysisPaneState extends State<TerrainAnalysisPane> {
  late final _controller = TerrainAnalysisController.fromEditor(
    widget.editing.maps,
    widget.loader,
  );
  StreamSubscription<void>? _changes;
  final _fields = {
    for (final e in {'x': '128', 'y': '128', 'radius': '128'}.entries)
      e.key: TextEditingController(text: e.value),
  };
  MapDistanceMeasurement? _measurement;
  String? _error;
  @override
  void initState() {
    super.initState();
    _changes = _controller.changes.listen((_) {
      if (mounted) setState(() => _measurement = null);
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    unawaited(_controller.dispose());
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final okay = await _controller.load();
      if (mounted) {
        setState(() => _error = okay ? null : 'ANALYSIS_DATA_UNAVAILABLE');
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _measure() {
    try {
      final view = _controller.view!;
      final measure = MapDistanceMeasurement(
        x: int.parse(_fields['x']!.text),
        y: int.parse(_fields['y']!.text),
        radius: int.parse(_fields['radius']!.text),
      );
      if (measure.x >= view.width * 32 || measure.y >= view.height * 32) {
        throw RangeError('ANALYSIS_DISTANCE_BOUNDS');
      }
      setState(() {
        _measurement = measure;
        _error = null;
      });
    } on Object catch (e) {
      setState(() {
        _measurement = null;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, view = _controller.view;
    if (view == null) return Center(child: Text(l.basicOpenMap));
    final mode = _controller.mode, source = _controller.source;
    String label(TerrainAnalysisMode value) => switch (value) {
      TerrainAnalysisMode.off => l.analysisOff,
      TerrainAnalysisMode.elevation => l.analysisElevation,
      TerrainAnalysisMode.buildable => l.analysisBuildable,
      TerrainAnalysisMode.walkable => l.analysisWalkable,
      TerrainAnalysisMode.power => l.analysisPower,
      TerrainAnalysisMode.creep => l.analysisCreep,
      TerrainAnalysisMode.distance => l.analysisDistance,
    };
    final unavailable =
        mode == TerrainAnalysisMode.power || mode == TerrainAnalysisMode.creep;
    return ListView(
      key: const Key('analysis-list'),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<TerrainAnalysisMode>(
                key: const Key('analysis-mode'),
                initialValue: mode,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.analysisTitle),
                items: [
                  for (final value in TerrainAnalysisMode.values)
                    DropdownMenuItem(value: value, child: Text(label(value))),
                ],
                onChanged: (v) {
                  if (v != null) _controller.setMode(v);
                },
              ),
            ),
            OutlinedButton.icon(
              key: const Key('analysis-load'),
              onPressed: _controller.loading || widget.loader == null
                  ? null
                  : _load,
              icon: const Icon(Icons.refresh),
              label: Text(l.analysisLoad),
            ),
            if (_controller.loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          unavailable
              ? l.analysisRuntimeUnsupported
              : mode == TerrainAnalysisMode.distance
              ? l.analysisDistanceOnly
              : source == null ||
                    (mode == TerrainAnalysisMode.elevation &&
                        source.snapshot.midElevationMasks == null)
              ? l.analysisUnknown
              : l.analysisStaticOnly,
          key: const Key('analysis-status'),
        ),
        if (source != null)
          SelectableText(
            '${source.storageProduct} / ${source.storageBuildNumber}'
            ' · helper ${source.helperVersion}\n${source.revision}',
          ),
        if (mode != TerrainAnalysisMode.off &&
            mode != TerrainAnalysisMode.distance)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final (color, text) in [
                  (
                    const Color(0xFF44B888),
                    mode == TerrainAnalysisMode.elevation
                        ? l.analysisLow
                        : l.analysisYes,
                  ),
                  if (mode == TerrainAnalysisMode.elevation)
                    (const Color(0xFF6587E8), l.analysisMid),
                  (
                    const Color(0xFFEF6470),
                    mode == TerrainAnalysisMode.elevation
                        ? l.analysisHigh
                        : l.analysisNo,
                  ),
                  (const Color(0xFFE8BD55), l.analysisMixed),
                  (const Color(0xFF7D8796), l.analysisUnknown),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 12, color: color),
                      const SizedBox(width: 5),
                      Text(text),
                    ],
                  ),
              ],
            ),
          ),
        if (mode == TerrainAnalysisMode.distance) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final (name, label) in [
                ('x', l.analysisPixelX),
                ('y', l.analysisPixelY),
                ('radius', l.analysisRadius),
              ])
                SizedBox(
                  width: 140,
                  child: TextField(
                    key: Key('analysis-$name'),
                    controller: _fields[name],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: label),
                    onChanged: (_) => setState(() => _measurement = null),
                  ),
                ),
              IconButton(
                key: const Key('analysis-measure'),
                tooltip: l.analysisMeasure,
                onPressed: _measure,
                icon: const Icon(Icons.straighten),
              ),
            ],
          ),
        ],
        if (_error != null)
          SelectableText(
            '${l.analysisRejected}\n$_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 380,
          child: MapCanvas(
            key: const Key('analysis-canvas'),
            mapWidth: view.width,
            mapHeight: view.height,
            rawTileValues: view.rawValues,
            analysisView: view,
            analysisMode: mode,
            distanceMeasurement: _measurement,
            terrainTextureState: widget.textures,
            onCanvasSelected: (point) {
              _fields['x']!.text = '${point.pixelX}';
              _fields['y']!.text = '${point.pixelY}';
              setState(() => _measurement = null);
            },
          ),
        ),
      ],
    );
  }
}
