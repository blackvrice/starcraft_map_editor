import 'dart:math' as math;

import 'package:flutter/material.dart';

class MapCanvas extends StatelessWidget {
  const MapCanvas({
    required this.mapWidth,
    required this.mapHeight,
    this.rawTileValues,
    this.contentPadding = 24,
    this.maximumTileExtent = 32,
    super.key,
  }) : assert(mapWidth > 0),
       assert(mapHeight > 0),
       assert(contentPadding >= 0),
       assert(maximumTileExtent > 0);

  final int mapWidth;
  final int mapHeight;
  final List<int>? rawTileValues;
  final double contentPadding;
  final double maximumTileExtent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('map-canvas'),
      color: MapCanvasPainter.viewportBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth ||
              !constraints.hasBoundedHeight ||
              constraints.maxWidth <= 0 ||
              constraints.maxHeight <= 0) {
            return const SizedBox.shrink();
          }

          final viewportSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final layout = MapCanvasLayout.fit(
            viewportSize: viewportSize,
            mapWidth: mapWidth,
            mapHeight: mapHeight,
            contentPadding: contentPadding,
            maximumTileExtent: maximumTileExtent,
          );
          final expectedTileCount = mapWidth * mapHeight;
          final terrainValues =
              rawTileValues != null &&
                  rawTileValues!.length == expectedTileCount
              ? rawTileValues
              : null;

          return Semantics(
            label:
                'Map canvas, $mapWidth by $mapHeight tiles, '
                '${terrainValues == null ? 'geometry preview' : 'terrain preview'}',
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    key: const Key('map-canvas-repaint-boundary'),
                    child: CustomPaint(
                      key: const Key('map-canvas-paint'),
                      painter: MapCanvasPainter(
                        layout: layout,
                        rawTileValues: terrainValues,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _CanvasBadge(
                    key: const Key('map-canvas-visible-region'),
                    icon: Icons.crop_free_rounded,
                    label:
                        'Visible '
                        '${layout.visibleTiles.left},'
                        '${layout.visibleTiles.top}–'
                        '${layout.visibleTiles.rightExclusive},'
                        '${layout.visibleTiles.bottomExclusive}',
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _CanvasBadge(
                    key: const Key('map-canvas-grid-scale'),
                    icon: Icons.grid_4x4_rounded,
                    label: 'Grid ${layout.gridStep} tile',
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _CanvasBadge(
                    key: const Key('map-canvas-render-mode'),
                    icon: terrainValues == null
                        ? Icons.border_all_rounded
                        : Icons.texture_rounded,
                    label: terrainValues == null
                        ? 'Geometry only'
                        : 'Raw MTXM preview',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MapCanvasLayout {
  const MapCanvasLayout({
    required this.viewportSize,
    required this.mapWidth,
    required this.mapHeight,
    required this.mapRect,
    required this.tileExtent,
    required this.visibleTiles,
    required this.gridStep,
  });

  factory MapCanvasLayout.fit({
    required Size viewportSize,
    required int mapWidth,
    required int mapHeight,
    double contentPadding = 24,
    double maximumTileExtent = 32,
  }) {
    if (mapWidth <= 0) {
      throw RangeError.value(
        mapWidth,
        'mapWidth',
        'Must be greater than zero.',
      );
    }
    if (mapHeight <= 0) {
      throw RangeError.value(
        mapHeight,
        'mapHeight',
        'Must be greater than zero.',
      );
    }
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      throw ArgumentError.value(
        viewportSize,
        'viewportSize',
        'Both dimensions must be greater than zero.',
      );
    }
    if (contentPadding < 0) {
      throw RangeError.value(
        contentPadding,
        'contentPadding',
        'Cannot be negative.',
      );
    }
    if (maximumTileExtent <= 0) {
      throw RangeError.value(
        maximumTileExtent,
        'maximumTileExtent',
        'Must be greater than zero.',
      );
    }

    final availableWidth = math.max(
      1.0,
      viewportSize.width - contentPadding * 2,
    );
    final availableHeight = math.max(
      1.0,
      viewportSize.height - contentPadding * 2,
    );
    final tileExtent = math.min(
      maximumTileExtent,
      math.min(availableWidth / mapWidth, availableHeight / mapHeight),
    );
    final mapPixelWidth = mapWidth * tileExtent;
    final mapPixelHeight = mapHeight * tileExtent;
    final mapRect = Rect.fromLTWH(
      (viewportSize.width - mapPixelWidth) / 2,
      (viewportSize.height - mapPixelHeight) / 2,
      mapPixelWidth,
      mapPixelHeight,
    );
    final viewportRect = Offset.zero & viewportSize;
    final visibleRect = mapRect.intersect(viewportRect);
    final visibleTiles = _visibleTileBounds(
      visibleRect: visibleRect,
      mapRect: mapRect,
      tileExtent: tileExtent,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
    );

    return MapCanvasLayout(
      viewportSize: viewportSize,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      mapRect: mapRect,
      tileExtent: tileExtent,
      visibleTiles: visibleTiles,
      gridStep: _gridStepFor(
        tileExtent: tileExtent,
        maximumDimension: math.max(mapWidth, mapHeight),
      ),
    );
  }

  final Size viewportSize;
  final int mapWidth;
  final int mapHeight;
  final Rect mapRect;
  final double tileExtent;
  final MapCanvasVisibleTiles visibleTiles;
  final int gridStep;
}

class MapCanvasVisibleTiles {
  const MapCanvasVisibleTiles({
    required this.left,
    required this.top,
    required this.rightExclusive,
    required this.bottomExclusive,
  });

  final int left;
  final int top;
  final int rightExclusive;
  final int bottomExclusive;

  bool get isEmpty => left >= rightExclusive || top >= bottomExclusive;
}

class MapCanvasPainter extends CustomPainter {
  MapCanvasPainter({required this.layout, required this.rawTileValues})
    : assert(
        rawTileValues == null ||
            rawTileValues.length == layout.mapWidth * layout.mapHeight,
      );

  static const viewportBackground = Color(0xFF0C1016);
  static const mapBackground = Color(0xFF17202A);
  static const mapBoundary = Color(0xFF70A1FF);
  static const minorGrid = Color(0x263E536F);
  static const majorGrid = Color(0x665E789D);

  static const _tilePalette = <Color>[
    Color(0xFF27384A),
    Color(0xFF334B43),
    Color(0xFF4C4433),
    Color(0xFF4B3544),
    Color(0xFF2E4554),
    Color(0xFF3F5037),
    Color(0xFF55452F),
    Color(0xFF493B57),
    Color(0xFF30475E),
    Color(0xFF3B594C),
    Color(0xFF5C5038),
    Color(0xFF593F4F),
    Color(0xFF375365),
    Color(0xFF486040),
    Color(0xFF68543A),
    Color(0xFF564566),
  ];

  final MapCanvasLayout layout;
  final List<int>? rawTileValues;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = viewportBackground);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final mapRect = layout.mapRect;
    canvas.drawRect(mapRect, Paint()..color = mapBackground);
    _paintTerrain(canvas);
    _paintGrid(canvas);
    canvas.drawRect(
      mapRect,
      Paint()
        ..color = mapBoundary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.restore();
  }

  void _paintTerrain(Canvas canvas) {
    final values = rawTileValues;
    final bounds = layout.visibleTiles;
    if (values == null || bounds.isEmpty) {
      return;
    }

    final paint = Paint();
    for (var y = bounds.top; y < bounds.bottomExclusive; y++) {
      for (var x = bounds.left; x < bounds.rightExclusive; x++) {
        final rawValue = values[y * layout.mapWidth + x];
        paint.color = _tilePalette[_paletteIndex(rawValue)];
        canvas.drawRect(
          Rect.fromLTWH(
            layout.mapRect.left + x * layout.tileExtent,
            layout.mapRect.top + y * layout.tileExtent,
            layout.tileExtent,
            layout.tileExtent,
          ),
          paint,
        );
      }
    }
  }

  void _paintGrid(Canvas canvas) {
    final bounds = layout.visibleTiles;
    if (bounds.isEmpty) {
      return;
    }

    final step = layout.gridStep;
    final mapRect = layout.mapRect;
    final gridPaint = Paint()
      ..color = step == 1 ? minorGrid : majorGrid
      ..strokeWidth = 1;
    final firstColumn = _firstMultipleAtOrAfter(bounds.left, step);
    final firstRow = _firstMultipleAtOrAfter(bounds.top, step);

    for (var x = firstColumn; x <= bounds.rightExclusive; x += step) {
      final pixelX = mapRect.left + x * layout.tileExtent;
      canvas.drawLine(
        Offset(pixelX, mapRect.top),
        Offset(pixelX, mapRect.bottom),
        gridPaint,
      );
    }
    for (var y = firstRow; y <= bounds.bottomExclusive; y += step) {
      final pixelY = mapRect.top + y * layout.tileExtent;
      canvas.drawLine(
        Offset(mapRect.left, pixelY),
        Offset(mapRect.right, pixelY),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MapCanvasPainter oldDelegate) {
    return oldDelegate.layout.viewportSize != layout.viewportSize ||
        oldDelegate.layout.mapWidth != layout.mapWidth ||
        oldDelegate.layout.mapHeight != layout.mapHeight ||
        oldDelegate.layout.mapRect != layout.mapRect ||
        oldDelegate.layout.tileExtent != layout.tileExtent ||
        oldDelegate.layout.gridStep != layout.gridStep ||
        !identical(oldDelegate.rawTileValues, rawTileValues);
  }
}

class _CanvasBadge extends StatelessWidget {
  const _CanvasBadge({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE6171C24),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF344056)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: const Color(0xFF9EBEFF)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD2D9E6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

MapCanvasVisibleTiles _visibleTileBounds({
  required Rect visibleRect,
  required Rect mapRect,
  required double tileExtent,
  required int mapWidth,
  required int mapHeight,
}) {
  if (visibleRect.isEmpty) {
    return const MapCanvasVisibleTiles(
      left: 0,
      top: 0,
      rightExclusive: 0,
      bottomExclusive: 0,
    );
  }

  final left = ((visibleRect.left - mapRect.left) / tileExtent)
      .floor()
      .clamp(0, mapWidth)
      .toInt();
  final top = ((visibleRect.top - mapRect.top) / tileExtent)
      .floor()
      .clamp(0, mapHeight)
      .toInt();
  final right = ((visibleRect.right - mapRect.left) / tileExtent)
      .ceil()
      .clamp(0, mapWidth)
      .toInt();
  final bottom = ((visibleRect.bottom - mapRect.top) / tileExtent)
      .ceil()
      .clamp(0, mapHeight)
      .toInt();

  return MapCanvasVisibleTiles(
    left: left,
    top: top,
    rightExclusive: right,
    bottomExclusive: bottom,
  );
}

int _gridStepFor({required double tileExtent, required int maximumDimension}) {
  var step = 1;
  while (tileExtent * step < 8 && step < maximumDimension) {
    step *= 2;
  }
  return step;
}

int _firstMultipleAtOrAfter(int value, int step) {
  return ((value + step - 1) ~/ step) * step;
}

int _paletteIndex(int rawValue) {
  return (rawValue ^ (rawValue >> 4) ^ (rawValue >> 8)) &
      (MapCanvasPainter._tilePalette.length - 1);
}
