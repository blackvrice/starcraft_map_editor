import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/placement/placement_catalog_controller.dart';

class WeaponImpactPanel extends StatefulWidget {
  const WeaponImpactPanel({
    required this.controller,
    required this.weapon,
    super.key,
  });
  final PlacementCatalogController controller;
  final int weapon;
  @override
  State<WeaponImpactPanel> createState() => _WeaponImpactPanelState();
}

class _WeaponImpactPanelState extends State<WeaponImpactPanel> {
  late Future<WeaponReferenceSnapshot> _future;
  late int _epoch;
  StreamSubscription<PlacementCatalogState>? _subscription;
  @override
  void initState() {
    super.initState();
    _load();
    _subscription = widget.controller.changes.listen((_) {
      if (_epoch != widget.controller.weaponReferenceEpoch) setState(_load);
    });
  }

  void _load() {
    _epoch = widget.controller.weaponReferenceEpoch;
    _future = widget.controller.loadWeaponReferences();
    // A synchronous stream invalidation can fail before the next frame attaches
    // FutureBuilder. Observe errors immediately; FutureBuilder still shows them.
    unawaited(_future.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WeaponReferenceSnapshot>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Text('Loading local weapon references…');
      }
      final result = snapshot.data;
      if (snapshot.hasError ||
          result == null ||
          result.epoch != widget.controller.weaponReferenceEpoch) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weapon reference list unavailable: ${snapshot.error ?? "source changed"}',
            ),
            TextButton(
              onPressed: () => setState(_load),
              child: const Text('Reload weapon references'),
            ),
          ],
        );
      }
      String names(List<int> ids) => ids.isEmpty
          ? 'None in this DAT snapshot'
          : ids.map((id) => 'Unit #$id').join(', ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weapon #${widget.weapon} — direct ground/air references: ${names(result.index.directUsers(widget.weapon))}',
            key: const Key('weapon-direct-users'),
          ),
          Text(
            'Units referencing those subunits: ${names(result.index.subunitUsers(widget.weapon))}',
            key: const Key('weapon-subunit-users'),
          ),
          Text('Source: ${result.source}'),
          const Text(
            'DAT references only. Spells, spawned projectiles/units and EUD runtime changes may have additional effects.',
          ),
        ],
      );
    },
  );
}
