import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../application/placement/placement_catalog_controller.dart';
import 'default_unit_names.dart';
import 'default_settings_names.dart';

/// Local game imagery and verified DAT links; never changes map values.
class UnitContextCard extends StatefulWidget {
  const UnitContextCard({
    required this.unit,
    this.catalog,
    required this.onWeapon,
    required this.onUnit,
    super.key,
  });
  final int unit;
  final PlacementCatalogController? catalog;
  final ValueChanged<int> onWeapon;
  final ValueChanged<int> onUnit;
  @override
  State<UnitContextCard> createState() => _UnitContextCardState();
}

class _UnitContextCardState extends State<UnitContextCard> {
  StreamSubscription<PlacementCatalogState>? _subscription;
  WeaponReferenceSnapshot? _references;
  ui.Image? _image;
  int _request = 0;
  int? _epoch;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _subscription?.cancel();
    _subscription = widget.catalog?.changes.listen((_) {
      if (_epoch != widget.catalog?.weaponReferenceEpoch) _load();
    });
    _load();
  }

  @override
  void didUpdateWidget(UnitContextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog) {
      _bind();
    } else if (oldWidget.unit != widget.unit) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final catalog = widget.catalog;
    final unit = widget.unit;
    _epoch = catalog?.weaponReferenceEpoch;
    setState(() {
      _references = null;
      _error = null;
      _loading = catalog != null;
      _image?.dispose();
      _image = null;
    });
    if (catalog == null) return;
    unawaited(_preview(catalog, unit, request));
    try {
      final references = await catalog.loadWeaponReferences();
      if (!mounted ||
          request != _request ||
          references.epoch != catalog.weaponReferenceEpoch) {
        return;
      }
      setState(() {
        _references = references;
        _loading = false;
      });
      final preferred = references.index.preferredWeapon(unit);
      if (preferred != null) widget.onWeapon(preferred.weapon);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error =
              'Local weapon references unavailable. Configure StarCraft assets and retry.';
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _preview(
    PlacementCatalogController catalog,
    int unit,
    int request,
  ) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      final item = await catalog.loadUnitPreview(unit);
      if (item == null ||
          !item.hasThumbnail ||
          !mounted ||
          request != _request) {
        return;
      }
      buffer = await ui.ImmutableBuffer.fromUint8List(item.thumbnailRgba!);
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: item.thumbnailWidth,
        height: item.thumbnailHeight,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      if (!mounted || request != _request) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      /* The name and ID remain usable without graphics. */
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  void dispose() {
    _request++;
    _subscription?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = _references?.index.units[widget.unit];
    final preferred = _references?.index.preferredWeapon(widget.unit);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xff101b23),
                  child: _image == null
                      ? const Icon(Icons.person_outline, color: Colors.blueGrey)
                      : RawImage(
                          image: _image,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${defaultUnitNames[widget.unit]}\nUnit #${widget.unit}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (_image == null)
              const Text('Unit preview requires local StarCraft graphics.'),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (widget.catalog == null)
              const Text('Configure StarCraft assets to load unit links.'),
            if (ref != null) ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final slot in [('Ground', ref.ground), ('Air', ref.air)])
                    ActionChip(
                      avatar: Icon(
                        slot.$1 == 'Ground' ? Icons.gps_fixed : Icons.flight,
                        size: 18,
                      ),
                      label: Text(
                        slot.$2 == 130
                            ? '${slot.$1}: None'
                            : '${slot.$1}: ${defaultWeaponNames[slot.$2]} (#${slot.$2})',
                      ),
                      onPressed: slot.$2 == 130
                          ? null
                          : () => widget.onWeapon(slot.$2),
                    ),
                  for (final subunit in {
                    ref.subunit1,
                    ref.subunit2,
                  }.where((id) => id < 228 && id != widget.unit))
                    ActionChip(
                      avatar: const Icon(Icons.account_tree, size: 18),
                      label: Text(
                        'Subunit: ${defaultUnitNames[subunit]} (#$subunit)',
                      ),
                      onPressed: () => widget.onUnit(subunit),
                    ),
                ],
              ),
              Text(
                preferred == null
                    ? 'No linked weapon. Select a weapon manually.'
                    : 'Auto-selected: ${defaultWeaponNames[preferred.weapon]} (#${preferred.weapon}) from ${defaultUnitNames[preferred.unit]}. Weapon changes affect all units sharing it.',
              ),
            ],
            if (_error != null)
              TextButton(
                onPressed: _load,
                child: const Text('Retry unit links'),
              ),
          ],
        ),
      ),
    );
  }
}
