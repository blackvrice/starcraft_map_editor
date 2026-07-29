import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/terrain/terrain_editing_controller.dart';
import '../../domain/terrain/terrain_tile_display_value.dart';

class MapCanvas extends StatefulWidget {
  const MapCanvas({
    required this.mapWidth,
    required this.mapHeight,
    this.rawTileValues,
    this.editingTool = TerrainEditingTool.select,
    this.selectedTile,
    this.onTileSelected,
    this.onBrushStrokeStarted,
    this.onBrushStroke,
    this.onBrushStrokeEnded,
    this.onBrushStrokeCancelled,
    this.onRectangleFilled,
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
  final TerrainEditingTool editingTool;
  final TerrainTileCoordinate? selectedTile;
  final ValueChanged<TerrainTileCoordinate>? onTileSelected;
  final VoidCallback? onBrushStrokeStarted;
  final ValueChanged<List<TerrainTileCoordinate>>? onBrushStroke;
  final VoidCallback? onBrushStrokeEnded;
  final VoidCallback? onBrushStrokeCancelled;
  final ValueChanged<TerrainTileRegion>? onRectangleFilled;
  final double contentPadding;
  final double maximumTileExtent;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  static const _minimumZoom = 0.25;
  static const _maximumZoom = 32.0;
  static const _zoomStep = 1.25;

  final FocusNode _focusNode = FocusNode(debugLabel: 'Map canvas');

  double _zoom = 1;
  Offset _requestedPan = Offset.zero;
  Offset? _pointerPosition;
  int? _activePanPointer;
  Offset? _dragStartPosition;
  Offset? _dragStartPan;
  int? _activeEditPointer;
  TerrainTileCoordinate? _lastBrushTile;
  TerrainTileCoordinate? _rectangleStart;
  TerrainTileCoordinate? _rectangleEnd;
  List<int>? _summarizedRawTileValues;
  TerrainTileDisplaySummary? _terrainDisplaySummary;

  @override
  void didUpdateWidget(MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapWidth != widget.mapWidth ||
        oldWidget.mapHeight != widget.mapHeight) {
      _resetCamera(notify: false);
    } else if (oldWidget.editingTool != widget.editingTool) {
      _cancelEditGesture(notify: false);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

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
          final layout = MapCanvasLayout.view(
            viewportSize: viewportSize,
            mapWidth: widget.mapWidth,
            mapHeight: widget.mapHeight,
            zoom: _zoom,
            panOffset: _requestedPan,
            contentPadding: widget.contentPadding,
            maximumTileExtent: widget.maximumTileExtent,
          );
          final expectedTileCount = widget.mapWidth * widget.mapHeight;
          final terrainValues =
              widget.rawTileValues != null &&
                  widget.rawTileValues!.length == expectedTileCount
              ? widget.rawTileValues
              : null;
          final terrainDisplaySummary = _displaySummaryFor(terrainValues);
          final coordinate = _pointerPosition == null
              ? null
              : layout.coordinateAt(_pointerPosition!);
          final rectanglePreview =
              _rectangleStart == null || _rectangleEnd == null
              ? null
              : TerrainTileRegion.fromCorners(_rectangleStart!, _rectangleEnd!);

          return Focus(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: MouseRegion(
              cursor: _cursor,
              onHover: (event) => _updatePointerPosition(event.localPosition),
              onExit: (_) {
                if (_activePanPointer == null) {
                  _updatePointerPosition(null);
                }
              },
              child: Listener(
                key: const Key('map-canvas-input'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _startInteraction(event, layout),
                onPointerMove: (event) => _updateInteraction(event, layout),
                onPointerUp: (event) =>
                    _stopInteraction(event, cancelled: false),
                onPointerCancel: (event) =>
                    _stopInteraction(event, cancelled: true),
                onPointerSignal: (event) => _handlePointerSignal(event, layout),
                child: Semantics(
                  label:
                      'Map canvas, ${widget.mapWidth} by '
                      '${widget.mapHeight} tiles, '
                      '${terrainValues == null ? 'geometry preview' : 'raw terrain fallback'}, '
                      '${terrainDisplaySummary?.unsupportedTileCount ?? 0} '
                      'unsupported tiles, '
                      '${widget.editingTool.name} tool, '
                      '${(_zoom * 100).round()} percent zoom',
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
                              selectedTile: widget.selectedTile,
                              rectanglePreview: rectanglePreview,
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
                              : terrainDisplaySummary!.hasUnsupportedTiles
                              ? Icons.warning_amber_rounded
                              : Icons.texture_rounded,
                          label: terrainValues == null
                              ? 'Geometry only'
                              : terrainDisplaySummary!.hasUnsupportedTiles
                              ? 'Raw fallback · '
                                    '${terrainDisplaySummary.unsupportedTileCount} '
                                    'unsupported'
                              : 'Raw fallback',
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Align(
                          child: _CanvasBadge(
                            key: const Key('map-canvas-coordinate'),
                            icon: Icons.my_location_rounded,
                            label: coordinate == null
                                ? 'Tile — · Pixel —'
                                : 'Tile ${coordinate.tileX},${coordinate.tileY}'
                                      ' · Pixel ${coordinate.pixelX},'
                                      '${coordinate.pixelY}',
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _CanvasZoomControls(
                          zoom: _zoom,
                          canZoomOut: _zoom > _minimumZoom,
                          canZoomIn: _zoom < _maximumZoom,
                          onZoomOut: () => _zoomAt(
                            _zoom / _zoomStep,
                            layout.viewportSize.center(Offset.zero),
                            layout,
                          ),
                          onFit: () => _resetCamera(),
                          onZoomIn: () => _zoomAt(
                            _zoom * _zoomStep,
                            layout.viewportSize.center(Offset.zero),
                            layout,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event, MapCanvasLayout layout) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final scrollAmount = event.scrollDelta.dy != 0
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (scrollAmount == 0) {
      return;
    }

    _zoomAt(
      scrollAmount < 0 ? _zoom * _zoomStep : _zoom / _zoomStep,
      event.localPosition,
      layout,
    );
  }

  TerrainTileDisplaySummary? _displaySummaryFor(List<int>? rawTileValues) {
    if (identical(rawTileValues, _summarizedRawTileValues)) {
      return _terrainDisplaySummary;
    }
    _summarizedRawTileValues = rawTileValues;
    _terrainDisplaySummary = rawTileValues == null
        ? null
        : TerrainTileDisplaySummary.fromRawValues(rawTileValues);
    return _terrainDisplaySummary;
  }

  void _zoomAt(
    double requestedZoom,
    Offset focalPoint,
    MapCanvasLayout layout,
  ) {
    final zoom = requestedZoom.clamp(_minimumZoom, _maximumZoom).toDouble();
    if (zoom == _zoom) {
      return;
    }

    final tileX = (focalPoint.dx - layout.mapRect.left) / layout.tileExtent;
    final tileY = (focalPoint.dy - layout.mapRect.top) / layout.tileExtent;
    final tileExtent = layout.baseTileExtent * zoom;
    final centeredLeft =
        (layout.viewportSize.width - widget.mapWidth * tileExtent) / 2;
    final centeredTop =
        (layout.viewportSize.height - widget.mapHeight * tileExtent) / 2;

    setState(() {
      _zoom = zoom;
      _requestedPan = Offset(
        focalPoint.dx - tileX * tileExtent - centeredLeft,
        focalPoint.dy - tileY * tileExtent - centeredTop,
      );
      _pointerPosition = focalPoint;
    });
  }

  MouseCursor get _cursor {
    if (_activePanPointer != null) {
      return SystemMouseCursors.grabbing;
    }
    return switch (widget.editingTool) {
      TerrainEditingTool.select => SystemMouseCursors.precise,
      TerrainEditingTool.brush => SystemMouseCursors.click,
      TerrainEditingTool.rectangle => SystemMouseCursors.precise,
    };
  }

  void _startInteraction(PointerDownEvent event, MapCanvasLayout layout) {
    _focusNode.requestFocus();
    _updatePointerPosition(event.localPosition);

    final isMiddleButton = event.buttons & kMiddleMouseButton != 0;
    final isSpacePrimary =
        event.buttons & kPrimaryMouseButton != 0 &&
        HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space);
    if (!isMiddleButton && !isSpacePrimary) {
      if (event.buttons & kPrimaryMouseButton != 0) {
        _startEditGesture(event, layout);
      }
      return;
    }

    setState(() {
      _activePanPointer = event.pointer;
      _dragStartPosition = event.localPosition;
      _dragStartPan = layout.panOffset;
    });
  }

  void _startEditGesture(PointerDownEvent event, MapCanvasLayout layout) {
    final coordinate = layout.coordinateAt(event.localPosition);
    if (coordinate == null) {
      return;
    }
    final tile = TerrainTileCoordinate(
      x: coordinate.tileX,
      y: coordinate.tileY,
    );

    switch (widget.editingTool) {
      case TerrainEditingTool.select:
        widget.onTileSelected?.call(tile);
      case TerrainEditingTool.brush:
        final onBrushStroke = widget.onBrushStroke;
        if (onBrushStroke == null) {
          return;
        }
        widget.onBrushStrokeStarted?.call();
        setState(() {
          _activeEditPointer = event.pointer;
          _lastBrushTile = tile;
        });
        onBrushStroke([tile]);
      case TerrainEditingTool.rectangle:
        if (widget.onRectangleFilled == null) {
          return;
        }
        setState(() {
          _activeEditPointer = event.pointer;
          _rectangleStart = tile;
          _rectangleEnd = tile;
        });
    }
  }

  void _updateInteraction(PointerMoveEvent event, MapCanvasLayout layout) {
    if (_activePanPointer == event.pointer &&
        _dragStartPosition != null &&
        _dragStartPan != null) {
      setState(() {
        _requestedPan =
            _dragStartPan! + event.localPosition - _dragStartPosition!;
        _pointerPosition = event.localPosition;
      });
      return;
    }

    if (_activeEditPointer != event.pointer) {
      _updatePointerPosition(event.localPosition);
      return;
    }

    final coordinate = layout.coordinateAt(event.localPosition);
    if (coordinate == null) {
      _updatePointerPosition(event.localPosition);
      return;
    }
    final tile = TerrainTileCoordinate(
      x: coordinate.tileX,
      y: coordinate.tileY,
    );

    switch (widget.editingTool) {
      case TerrainEditingTool.select:
        _updatePointerPosition(event.localPosition);
      case TerrainEditingTool.brush:
        final previous = _lastBrushTile;
        if (previous == null || previous == tile) {
          _updatePointerPosition(event.localPosition);
          return;
        }
        setState(() {
          _lastBrushTile = tile;
          _pointerPosition = event.localPosition;
        });
        widget.onBrushStroke?.call(_tileLine(previous, tile).skip(1).toList());
      case TerrainEditingTool.rectangle:
        if (_rectangleEnd == tile) {
          _updatePointerPosition(event.localPosition);
          return;
        }
        setState(() {
          _rectangleEnd = tile;
          _pointerPosition = event.localPosition;
        });
    }
  }

  void _stopInteraction(PointerEvent event, {required bool cancelled}) {
    if (_activePanPointer == event.pointer) {
      setState(() {
        _activePanPointer = null;
        _dragStartPosition = null;
        _dragStartPan = null;
        _pointerPosition = event.localPosition;
      });
      return;
    }

    if (_activeEditPointer != event.pointer) {
      return;
    }
    if (widget.editingTool == TerrainEditingTool.brush) {
      if (cancelled) {
        widget.onBrushStrokeCancelled?.call();
      } else {
        widget.onBrushStrokeEnded?.call();
      }
    }
    final start = _rectangleStart;
    final end = _rectangleEnd;
    if (!cancelled &&
        widget.editingTool == TerrainEditingTool.rectangle &&
        start != null &&
        end != null) {
      widget.onRectangleFilled?.call(TerrainTileRegion.fromCorners(start, end));
    }
    _cancelEditGesture(pointerPosition: event.localPosition);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _activeEditPointer != null) {
      if (widget.editingTool == TerrainEditingTool.brush) {
        widget.onBrushStrokeCancelled?.call();
      }
      _cancelEditGesture();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _cancelEditGesture({bool notify = true, Offset? pointerPosition}) {
    void cancel() {
      _activeEditPointer = null;
      _lastBrushTile = null;
      _rectangleStart = null;
      _rectangleEnd = null;
      if (pointerPosition != null) {
        _pointerPosition = pointerPosition;
      }
    }

    if (notify && mounted) {
      setState(cancel);
    } else {
      cancel();
    }
  }

  void _updatePointerPosition(Offset? position) {
    if (_pointerPosition == position) {
      return;
    }
    setState(() {
      _pointerPosition = position;
    });
  }

  void _resetCamera({bool notify = true}) {
    void reset() {
      _zoom = 1;
      _requestedPan = Offset.zero;
      _pointerPosition = null;
      _activePanPointer = null;
      _dragStartPosition = null;
      _dragStartPan = null;
      _activeEditPointer = null;
      _lastBrushTile = null;
      _rectangleStart = null;
      _rectangleEnd = null;
    }

    if (notify) {
      setState(reset);
    } else {
      reset();
    }
  }
}

class MapCanvasLayout {
  const MapCanvasLayout({
    required this.viewportSize,
    required this.mapWidth,
    required this.mapHeight,
    required this.mapRect,
    required this.baseTileExtent,
    required this.tileExtent,
    required this.zoom,
    required this.panOffset,
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
    return MapCanvasLayout.view(
      viewportSize: viewportSize,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      contentPadding: contentPadding,
      maximumTileExtent: maximumTileExtent,
    );
  }

  factory MapCanvasLayout.view({
    required Size viewportSize,
    required int mapWidth,
    required int mapHeight,
    double zoom = 1,
    Offset panOffset = Offset.zero,
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
    if (!zoom.isFinite || zoom <= 0) {
      throw RangeError.value(zoom, 'zoom', 'Must be finite and positive.');
    }
    if (!panOffset.dx.isFinite || !panOffset.dy.isFinite) {
      throw ArgumentError.value(
        panOffset,
        'panOffset',
        'Both dimensions must be finite.',
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
    final baseTileExtent = math.min(
      maximumTileExtent,
      math.min(availableWidth / mapWidth, availableHeight / mapHeight),
    );
    final tileExtent = baseTileExtent * zoom;
    final mapPixelWidth = mapWidth * tileExtent;
    final mapPixelHeight = mapHeight * tileExtent;
    final centeredMapRect = Rect.fromLTWH(
      (viewportSize.width - mapPixelWidth) / 2,
      (viewportSize.height - mapPixelHeight) / 2,
      mapPixelWidth,
      mapPixelHeight,
    );
    final constrainedPan = _constrainPanOffset(
      requestedPan: panOffset,
      centeredMapRect: centeredMapRect,
      viewportSize: viewportSize,
      contentPadding: contentPadding,
    );
    final mapRect = centeredMapRect.shift(constrainedPan);
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
      baseTileExtent: baseTileExtent,
      tileExtent: tileExtent,
      zoom: zoom,
      panOffset: constrainedPan,
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
  final double baseTileExtent;
  final double tileExtent;
  final double zoom;
  final Offset panOffset;
  final MapCanvasVisibleTiles visibleTiles;
  final int gridStep;

  MapCanvasPointerCoordinate? coordinateAt(Offset viewportPosition) {
    if (!mapRect.contains(viewportPosition)) {
      return null;
    }

    final pixelX = ((viewportPosition.dx - mapRect.left) / tileExtent * 32)
        .floor();
    final pixelY = ((viewportPosition.dy - mapRect.top) / tileExtent * 32)
        .floor();
    final maximumPixelX = mapWidth * 32 - 1;
    final maximumPixelY = mapHeight * 32 - 1;
    final boundedPixelX = pixelX.clamp(0, maximumPixelX).toInt();
    final boundedPixelY = pixelY.clamp(0, maximumPixelY).toInt();
    return MapCanvasPointerCoordinate(
      tileX: boundedPixelX ~/ 32,
      tileY: boundedPixelY ~/ 32,
      pixelX: boundedPixelX,
      pixelY: boundedPixelY,
    );
  }
}

class MapCanvasPointerCoordinate {
  const MapCanvasPointerCoordinate({
    required this.tileX,
    required this.tileY,
    required this.pixelX,
    required this.pixelY,
  });

  final int tileX;
  final int tileY;
  final int pixelX;
  final int pixelY;
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
  MapCanvasPainter({
    required this.layout,
    required this.rawTileValues,
    this.selectedTile,
    this.rectanglePreview,
  }) : assert(
         rawTileValues == null ||
             rawTileValues.length == layout.mapWidth * layout.mapHeight,
       );

  static const viewportBackground = Color(0xFF0C1016);
  static const mapBackground = Color(0xFF17202A);
  static const mapBoundary = Color(0xFF70A1FF);
  static const minorGrid = Color(0x263E536F);
  static const majorGrid = Color(0x665E789D);
  static const unsupportedTileBackground = Color(0xFF42162F);
  static const unsupportedTileMark = Color(0xFFFF6BAA);

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
  final TerrainTileCoordinate? selectedTile;
  final TerrainTileRegion? rectanglePreview;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = viewportBackground);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final mapRect = layout.mapRect;
    canvas.drawRect(mapRect, Paint()..color = mapBackground);
    _paintTerrain(canvas);
    _paintGrid(canvas);
    _paintEditOverlay(canvas);
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
        final tileRect = Rect.fromLTWH(
          layout.mapRect.left + x * layout.tileExtent,
          layout.mapRect.top + y * layout.tileExtent,
          layout.tileExtent,
          layout.tileExtent,
        );
        if (TerrainTileDisplayValue.isStandardRawValue(rawValue)) {
          paint.color = _tilePalette[_paletteIndex(rawValue)];
          canvas.drawRect(tileRect, paint);
        } else {
          _paintUnsupportedTile(canvas, tileRect);
        }
      }
    }
  }

  void _paintUnsupportedTile(Canvas canvas, Rect tileRect) {
    canvas.drawRect(tileRect, Paint()..color = unsupportedTileBackground);
    if (layout.tileExtent < 6) {
      return;
    }

    final markPaint = Paint()
      ..color = unsupportedTileMark
      ..strokeWidth = math.min(2, math.max(1, layout.tileExtent / 12));
    canvas.drawLine(tileRect.topLeft, tileRect.bottomRight, markPaint);
    canvas.drawLine(tileRect.topRight, tileRect.bottomLeft, markPaint);
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

  void _paintEditOverlay(Canvas canvas) {
    final selected = selectedTile;
    if (selected != null &&
        selected.x >= 0 &&
        selected.x < layout.mapWidth &&
        selected.y >= 0 &&
        selected.y < layout.mapHeight) {
      canvas.drawRect(
        _tileRect(selected.x, selected.y),
        Paint()
          ..color = const Color(0xFFF6C85F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final region = rectanglePreview;
    if (region != null) {
      final rect = Rect.fromLTRB(
        layout.mapRect.left + region.left * layout.tileExtent,
        layout.mapRect.top + region.top * layout.tileExtent,
        layout.mapRect.left + (region.right + 1) * layout.tileExtent,
        layout.mapRect.top + (region.bottom + 1) * layout.tileExtent,
      );
      canvas.drawRect(rect, Paint()..color = const Color(0x3370A1FF));
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF9EBEFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  Rect _tileRect(int x, int y) => Rect.fromLTWH(
    layout.mapRect.left + x * layout.tileExtent,
    layout.mapRect.top + y * layout.tileExtent,
    layout.tileExtent,
    layout.tileExtent,
  );

  @override
  bool shouldRepaint(covariant MapCanvasPainter oldDelegate) {
    return oldDelegate.layout.viewportSize != layout.viewportSize ||
        oldDelegate.layout.mapWidth != layout.mapWidth ||
        oldDelegate.layout.mapHeight != layout.mapHeight ||
        oldDelegate.layout.mapRect != layout.mapRect ||
        oldDelegate.layout.tileExtent != layout.tileExtent ||
        oldDelegate.layout.gridStep != layout.gridStep ||
        !identical(oldDelegate.rawTileValues, rawTileValues) ||
        oldDelegate.selectedTile != selectedTile ||
        oldDelegate.rectanglePreview?.left != rectanglePreview?.left ||
        oldDelegate.rectanglePreview?.top != rectanglePreview?.top ||
        oldDelegate.rectanglePreview?.right != rectanglePreview?.right ||
        oldDelegate.rectanglePreview?.bottom != rectanglePreview?.bottom;
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

class _CanvasZoomControls extends StatelessWidget {
  const _CanvasZoomControls({
    required this.zoom,
    required this.canZoomOut,
    required this.canZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onZoomIn,
  });

  final double zoom;
  final bool canZoomOut;
  final bool canZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6171C24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFF344056)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            key: const Key('map-canvas-zoom-out'),
            tooltip: 'Zoom out',
            icon: Icons.remove_rounded,
            onPressed: canZoomOut ? onZoomOut : null,
          ),
          Tooltip(
            message: 'Fit map to view',
            child: InkWell(
              key: const Key('map-canvas-fit'),
              onTap: onFit,
              child: SizedBox(
                width: 54,
                height: 28,
                child: Center(
                  child: Text(
                    '${(zoom * 100).round()}%',
                    key: const Key('map-canvas-zoom-level'),
                    style: const TextStyle(
                      color: Color(0xFFD2D9E6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _ZoomButton(
            key: const Key('map-canvas-zoom-in'),
            tooltip: 'Zoom in',
            icon: Icons.add_rounded,
            onPressed: canZoomIn ? onZoomIn : null,
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 15,
      color: const Color(0xFF9EBEFF),
      disabledColor: const Color(0xFF536076),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      visualDensity: VisualDensity.compact,
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

Offset _constrainPanOffset({
  required Offset requestedPan,
  required Rect centeredMapRect,
  required Size viewportSize,
  required double contentPadding,
}) {
  double constrainAxis({
    required double requested,
    required double mapStart,
    required double mapEnd,
    required double mapExtent,
    required double viewportExtent,
  }) {
    final edgePadding = math.min(contentPadding, viewportExtent / 2);
    final availableExtent = math.max(0, viewportExtent - edgePadding * 2);
    if (mapExtent <= availableExtent) {
      return 0;
    }

    final minimum = edgePadding - mapEnd;
    final maximum = viewportExtent - edgePadding - mapStart;
    return requested.clamp(minimum, maximum).toDouble();
  }

  return Offset(
    constrainAxis(
      requested: requestedPan.dx,
      mapStart: centeredMapRect.left,
      mapEnd: centeredMapRect.right,
      mapExtent: centeredMapRect.width,
      viewportExtent: viewportSize.width,
    ),
    constrainAxis(
      requested: requestedPan.dy,
      mapStart: centeredMapRect.top,
      mapEnd: centeredMapRect.bottom,
      mapExtent: centeredMapRect.height,
      viewportExtent: viewportSize.height,
    ),
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

Iterable<TerrainTileCoordinate> _tileLine(
  TerrainTileCoordinate start,
  TerrainTileCoordinate end,
) sync* {
  var x = start.x;
  var y = start.y;
  final deltaX = (end.x - start.x).abs();
  final stepX = start.x < end.x ? 1 : -1;
  final deltaY = -(end.y - start.y).abs();
  final stepY = start.y < end.y ? 1 : -1;
  var error = deltaX + deltaY;

  while (true) {
    yield TerrainTileCoordinate(x: x, y: y);
    if (x == end.x && y == end.y) {
      return;
    }
    final doubledError = error * 2;
    if (doubledError >= deltaY) {
      error += deltaY;
      x += stepX;
    }
    if (doubledError <= deltaX) {
      error += deltaX;
      y += stepY;
    }
  }
}
