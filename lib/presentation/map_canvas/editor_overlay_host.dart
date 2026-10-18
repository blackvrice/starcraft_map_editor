import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../../application/terrain/editor_overlay_controller.dart';

class EditorOverlayHost extends StatefulWidget {
  const EditorOverlayHost({
    required this.catalog,
    required this.builder,
    super.key,
  });
  final PlacementCatalogController catalog;
  final Widget Function(BuildContext, EditorOverlayController) builder;
  @override
  State<EditorOverlayHost> createState() => _EditorOverlayHostState();
}

class _EditorOverlayHostState extends State<EditorOverlayHost> {
  late EditorOverlayController _controller;
  StreamSubscription<void>? _subscription;
  void _attach() {
    _controller = EditorOverlayController(widget.catalog);
    _subscription = _controller.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(EditorOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.catalog, oldWidget.catalog)) {
      unawaited(_subscription?.cancel());
      unawaited(_controller.dispose());
      _attach();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
