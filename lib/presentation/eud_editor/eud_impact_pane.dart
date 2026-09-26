import 'package:flutter/material.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../../domain/eud/eud_override_impact.dart';
import '../../domain/eud/eud_field_manifest.dart';
import '../../domain/eud/eud_project.dart';
import '../settings/default_unit_names.dart';
import '../settings/default_settings_names.dart';
import '../settings/unit_context_card.dart';

class EudImpactPane extends StatefulWidget {
  const EudImpactPane({
    required this.project,
    this.catalog,
    this.onEditWeapon,
    this.onEditShields,
    this.onSelectWeapon,
    super.key,
  });
  final EudProject project;
  final PlacementCatalogController? catalog;
  final void Function(int weapon, int epoch)? onEditWeapon;
  final void Function(int unit)? onEditShields;
  final ValueChanged<int>? onSelectWeapon;

  @override
  State<EudImpactPane> createState() => _EudImpactPaneState();
}

class _EudImpactPaneState extends State<EudImpactPane> {
  WeaponReferenceSnapshot? _snapshot;
  String? _error;
  int? _errorEpoch;
  bool _loading = false;
  int _request = 0;
  int _unit = 0;

  @override
  void didUpdateWidget(EudImpactPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.catalog, widget.catalog)) {
      _request++;
      _snapshot = null;
      _error = null;
      _loading = false;
    }
  }

  Future<void> _load() async {
    final catalog = widget.catalog!;
    final request = ++_request;
    final epoch = catalog.weaponReferenceEpoch;
    setState(() {
      _loading = true;
      _snapshot = null;
      _error = null;
    });
    try {
      final result = await catalog.loadWeaponReferences();
      if (!mounted || request != _request) return;
      if (epoch == catalog.weaponReferenceEpoch && result.epoch == epoch) {
        setState(() => _snapshot = result);
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = error.toString();
          _errorEpoch = epoch;
        });
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PlacementCatalogState>(
    stream: widget.catalog?.changes,
    builder: (context, _) {
      final epoch = widget.catalog?.weaponReferenceEpoch;
      final snapshot = _snapshot?.epoch == epoch ? _snapshot : null;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Static unit / weapon impact'),
            const Text(
              'Base DAT references only; proposed reference changes, spells and actual attack behavior are not resolved. Type settings are global; player fields affect the selected slot.',
            ),
            OutlinedButton(
              onPressed: widget.catalog == null || _loading ? null : _load,
              child: const Text('Load weapon impact'),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (snapshot == null)
              const Text(
                'Weapon references unavailable. Load or reload to analyze.',
              )
            else
              Text('Reference source: ${snapshot.source}'),
            if (_error != null && _errorEpoch == epoch) Text(_error!),
            const Text(
              'Choose a unit to edit its direct ground / air weapon. Subunit weapons are separate; select that subunit explicitly.',
            ),
            SizedBox(
              width: 360,
              child: DropdownButton<int>(
                key: const Key('eud-reference-unit'),
                isExpanded: true,
                value: _unit,
                items: [
                  for (var i = 0; i < 228; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text('${defaultUnitNames[i]} (#$i)'),
                    ),
                ],
                onChanged: (value) => setState(() => _unit = value!),
              ),
            ),
            UnitContextCard(
              unit: _unit,
              catalog: widget.catalog,
              onUnit: (unit) => setState(() => _unit = unit),
              onWeapon: (weapon) => widget.onSelectWeapon?.call(weapon),
            ),
            OutlinedButton(
              onPressed: widget.onEditShields == null
                  ? null
                  : () => widget.onEditShields!(_unit),
              child: const Text('Edit unit EUD shields'),
            ),
            if (snapshot != null) ...[
              _weaponLink(
                'Ground',
                snapshot.index.units[_unit].ground,
                snapshot,
              ),
              _weaponLink('Air', snapshot.index.units[_unit].air, snapshot),
              Text(
                'Subunit IDs: ${snapshot.index.units[_unit].subunit1}, ${snapshot.index.units[_unit].subunit2} (228 = None)',
              ),
            ],
            for (final override in widget.project.overrides)
              _row(override, snapshot),
          ],
        ),
      );
    },
  );

  Widget _weaponLink(
    String slot,
    int weapon,
    WeaponReferenceSnapshot snapshot,
  ) {
    if (weapon == 130) return Text('$slot weapon: None (#130)');
    return OutlinedButton(
      key: Key('eud-reference-${slot.toLowerCase()}'),
      onPressed: widget.onEditWeapon == null
          ? null
          : () {
              if (snapshot.epoch == widget.catalog?.weaponReferenceEpoch) {
                widget.onEditWeapon!(weapon, snapshot.epoch);
              }
            },
      child: Text('$slot: ${defaultWeaponNames[weapon]} (#$weapon) — Edit EUD'),
    );
  }

  Widget _row(EudOverride override, WeaponReferenceSnapshot? snapshot) {
    final impact = EudOverrideImpact.analyze(
      override,
      references: snapshot?.index,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${override.identity}\n${impact.error != null
            ? 'Cannot analyze: ${impact.error!.name}'
            : impact.directUnits == null
            ? EudFieldManifest.find(override.field)?.table == EudTable.weapon
                  ? 'Impact unknown: weapon references unavailable.'
                  : EudFieldManifest.find(override.field)?.table == EudTable.player
                  ? 'Player ${override.targetId + 1} only; runtime behavior unverified.'
                  : 'Impact unknown: shared references for this table are unavailable.'
            : 'Direct units: ${_names(impact.directUnits!)}\nVia subunits: ${_names(impact.subunitUnits!)}'}',
      ),
    );
  }

  String _names(List<int> ids) => ids.isEmpty
      ? 'None in static references'
      : ids.map((id) => '${defaultUnitNames[id]} (#$id)').join(', ');
}
