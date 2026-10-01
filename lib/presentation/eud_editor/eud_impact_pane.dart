import 'package:flutter/material.dart';
import '../../domain/eud/eud_dat_snapshot.dart';
import 'eud_field_editor.dart';
import '../localization/l10n.dart';
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
      final result = catalog.eudDatGateway == null
          ? await catalog.loadWeaponReferences()
          : await (() async {
              final data = await catalog.loadEudData();
              return WeaponReferenceSnapshot(
                data.snapshot.weaponIndex(),
                epoch,
                data.label,
              );
            })();
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
      final l10n = context.l10n;
      final epoch = widget.catalog?.weaponReferenceEpoch;
      final snapshot = _snapshot?.epoch == epoch ? _snapshot : null;
      final data = widget.catalog?.eudData?.snapshot;
      final original = data?.graph();
      final planned = widget.project.validationIssues.isEmpty
          ? data?.graph(widget.project.overrides)
          : null;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  size: 18,
                  color: Color(0xFFA7AFB8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.eudImpactTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: widget.catalog == null || _loading ? null : _load,
                  child: Text(
                    widget.catalog?.eudDatGateway != null
                        ? l10n.eudDatLoad
                        : l10n.eudImpactLoad,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.eudImpactHelp,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFA7AFB8)),
            ),
            const SizedBox(height: 6),
            if (_loading) const LinearProgressIndicator(),
            if (snapshot == null && data == null)
              Text(l10n.eudImpactUnavailable)
            else
              Text(
                l10n.eudImpactSource(
                  snapshot?.source ?? widget.catalog!.eudData!.label,
                ),
              ),
            if (_error != null && _errorEpoch == epoch) Text(_error!),
            const SizedBox(height: 8),
            Text(l10n.eudImpactChooseUnit),
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
              child: Text(l10n.eudImpactEditShields),
            ),
            if (snapshot != null) ...[
              _weaponLink(
                l10n,
                'ground',
                l10n.eudImpactGround,
                snapshot.index.units[_unit].ground,
                snapshot,
              ),
              _weaponLink(
                l10n,
                'air',
                l10n.eudImpactAir,
                snapshot.index.units[_unit].air,
                snapshot,
              ),
              Text(
                l10n.eudImpactSubunits(
                  '${snapshot.index.units[_unit].subunit1}',
                  '${snapshot.index.units[_unit].subunit2}',
                ),
              ),
            ],
            if (planned != null)
              Text(l10n.eudDatPartial(planned.unresolved.length)),
            for (final override in widget.project.overrides)
              _row(l10n, override, snapshot, original, planned),
          ],
        ),
      );
    },
  );

  Widget _weaponLink(
    AppLocalizations l10n,
    String id,
    String slot,
    int weapon,
    WeaponReferenceSnapshot snapshot,
  ) {
    if (weapon == 130) return Text(l10n.eudImpactNoWeapon(slot));
    return OutlinedButton(
      key: Key('eud-reference-$id'),
      onPressed: widget.onEditWeapon == null
          ? null
          : () {
              if (snapshot.epoch == widget.catalog?.weaponReferenceEpoch) {
                widget.onEditWeapon!(weapon, snapshot.epoch);
              }
            },
      child: Text(
        l10n.eudImpactEditWeapon(
          slot,
          '${defaultWeaponNames[weapon]} (#$weapon)',
        ),
      ),
    );
  }

  Widget _row(
    AppLocalizations l10n,
    EudOverride override,
    WeaponReferenceSnapshot? snapshot,
    EudDatGraph? original,
    EudDatGraph? planned,
  ) {
    final impact = EudOverrideImpact.analyze(
      override,
      references: snapshot?.index,
    );
    final table = EudFieldManifest.find(override.field)?.table;
    final node = table == null ? null : (table: table, id: override.targetId);
    if (impact.error == null &&
        original != null &&
        planned != null &&
        node != null &&
        [
          EudTable.unit,
          EudTable.weapon,
          EudTable.flingy,
          EudTable.sprite,
          EudTable.image,
        ].contains(table)) {
      String names(List<EudDatNode> nodes) => nodes.isEmpty
          ? l10n.eudImpactNone
          : nodes.map((n) => eudTargetName(n.table, n.id)).join(', ');
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SelectableText(
          '${override.identity}\n${l10n.eudDatImpact(names([if (table == EudTable.unit) node, ...original.allUsers(node)]), names([if (table == EudTable.unit) node, ...planned.allUsers(node)]), names(planned.directUsers(node)))}',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${override.identity}\n${impact.error != null
            ? l10n.eudImpactCannotAnalyze(impact.error!.name)
            : impact.directUnits == null
            ? EudFieldManifest.find(override.field)?.table == EudTable.weapon
                  ? l10n.eudImpactUnknownWeapon
                  : EudFieldManifest.find(override.field)?.table == EudTable.player
                  ? l10n.eudImpactPlayerOnly('${override.targetId + 1}')
                  : l10n.eudImpactUnknownShared
            : l10n.eudImpactUnits(_names(l10n, impact.directUnits!), _names(l10n, impact.subunitUnits!))}',
      ),
    );
  }

  String _names(AppLocalizations l10n, List<int> ids) => ids.isEmpty
      ? l10n.eudImpactNone
      : ids.map((id) => '${defaultUnitNames[id]} (#$id)').join(', ');
}
