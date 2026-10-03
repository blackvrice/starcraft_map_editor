import '../localization/l10n.dart';
import 'default_unit_names.dart';
import 'default_settings_names.dart';
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
        return Text(context.l10n.editorLoadingLocalWeaponReferences);
      }
      final result = snapshot.data;
      if (snapshot.hasError ||
          result == null ||
          result.epoch != widget.controller.weaponReferenceEpoch) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.editorWeaponReferenceListUnavailable(
                (snapshot.error ?? context.l10n.editorSourceChanged).toString(),
              ),
            ),
            TextButton(
              onPressed: () => setState(_load),
              child: Text(context.l10n.editorReloadWeaponReferences),
            ),
          ],
        );
      }
      String names(List<int> ids) => ids.isEmpty
          ? context.l10n.editorNoneInThisDATSnapshot
          : ids
                .map(
                  (id) => settingsName(
                    context.l10n.editorUnit,
                    id,
                    defaultUnitNames,
                  ),
                )
                .join(', ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.editorWeaponDirectGroundAirReferences(
              (widget.weapon).toString(),
              (names(result.index.directUsers(widget.weapon))).toString(),
            ),
            key: const Key('weapon-direct-users'),
          ),
          Text(
            context.l10n.editorUnitsReferencingThoseSubunits(
              (names(result.index.subunitUsers(widget.weapon))).toString(),
            ),
            key: const Key('weapon-subunit-users'),
          ),
          Text(context.l10n.editorSource854c792f((result.source).toString())),
          Text(
            context
                .l10n
                .editorDATReferencesOnlySpellsSpawnedProjectilesUnitsAndEUD,
          ),
        ],
      );
    },
  );
}
