import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/placement/placement_catalog_controller.dart';
import '../../application/ports/starcraft_placement_catalog_gateway.dart';
import '../../application/ports/unit_power_state_gateway.dart';
import '../../domain/placement/unit_creep_catalog.dart';
import '../../domain/placement/unit_power_catalog.dart';
import '../localization/l10n.dart';
import 'placement_catalog_pane.dart';

/// Explicit, read-only queries. Editing coordinates never starts collection.
class PlacementEnvironmentDialog extends StatefulWidget {
  const PlacementEnvironmentDialog({required this.controller, super.key});
  final PlacementCatalogController controller;

  @override
  State<PlacementEnvironmentDialog> createState() => _EnvironmentState();
}

class _EnvironmentState extends State<PlacementEnvironmentDialog> {
  final _x = TextEditingController(text: '0');
  final _y = TextEditingController(text: '0');
  UnitPowerStateModel _model = UnitPowerStateModel.preplacedLayout;
  bool _powerBusy = false, _creepBusy = false;

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  Future<void> _load({required bool creep}) async {
    setState(() {
      if (creep) {
        _creepBusy = true;
      } else {
        _powerBusy = true;
      }
    });
    final controller = widget.controller;
    final model = _model;
    final selection = controller.state.selection;
    final session = controller.openMapController.state.session;
    try {
      if (!await controller.loadCollisionMetadata()) return;
      // Loading metadata may outlive this dialog; never start collection then.
      if (!mounted ||
          !identical(selection, controller.state.selection) ||
          !identical(session, controller.openMapController.state.session)) {
        return;
      }
      if (creep) {
        await controller.loadUnitCreepState(reload: true);
      } else {
        await controller.loadUnitPowerState(reload: true, model: model);
      }
    } finally {
      if (mounted) {
        setState(() {
          if (creep) {
            _creepBusy = false;
          } else {
            _powerBusy = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: widget.controller.changes,
    builder: (context, _) {
      final l10n = context.l10n;
      final controller = widget.controller;
      final x = int.tryParse(_x.text), y = int.tryParse(_y.text);
      final valid = x != null && y != null && x <= 65535 && y <= 65535;
      final power = valid
          ? controller.inspectUnitPowerAt(pixelX: x, pixelY: y, model: _model)
          : null;
      final creep = valid
          ? controller.inspectUnitCreepAt(pixelX: x, pixelY: y)
          : null;
      final selected =
          controller.state.selection?.kind == StarCraftPlacementKind.unit;
      final powerBusy = _powerBusy || controller.isUnitPowerStateLoading;
      final creepBusy = _creepBusy || controller.isUnitCreepStateLoading;
      final powerSupported = controller.supportsUnitPowerStateModel(_model);
      String powerText() => switch (power?.check) {
        UnitPowerCheck.powered => l10n.placementEnvironmentPowered,
        UnitPowerCheck.unpowered => l10n.placementEnvironmentUnpowered,
        UnitPowerCheck.notApplicable => l10n.placementPolicyNotApplicable,
        UnitPowerCheck.stateUnsupported => l10n.placementEnvironmentUnsupported,
        UnitPowerCheck.outOfBounds => l10n.placementEnvironmentOutside,
        _ => l10n.placementPolicyUnavailable,
      };
      String creepText() => switch (creep?.check) {
        UnitCreepCheck.covered => l10n.placementEnvironmentCreepPresent,
        UnitCreepCheck.missing => l10n.placementEnvironmentCreepMissing,
        UnitCreepCheck.notApplicable => l10n.placementPolicyNotApplicable,
        UnitCreepCheck.stateUnsupported => l10n.placementEnvironmentUnsupported,
        UnitCreepCheck.outOfBounds => l10n.placementEnvironmentOutside,
        _ => l10n.placementPolicyUnavailable,
      };
      return AlertDialog(
        key: const Key('placement-environment-dialog'),
        title: Text(l10n.placementEnvironmentTitle),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.state.selection?.displayName ??
                      l10n.placementPolicyNoTarget,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _coordinate(_x, 'X', 'environment-x')),
                    const SizedBox(width: 12),
                    Expanded(child: _coordinate(_y, 'Y', 'environment-y')),
                  ],
                ),
                if (!valid) Text(l10n.placementEnvironmentCoordinateRange),
                const SizedBox(height: 16),
                SegmentedButton<UnitPowerStateModel>(
                  key: const Key('environment-power-model'),
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  selected: {_model},
                  onSelectionChanged: powerBusy
                      ? null
                      : (values) => setState(() => _model = values.single),
                  style: const ButtonStyle(
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                    minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  segments: [
                    ButtonSegment(
                      value: UnitPowerStateModel.preplacedLayout,
                      label: Text(
                        l10n.placementEnvironmentLayout,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ButtonSegment(
                      value: UnitPowerStateModel.initialMap,
                      label: Text(
                        l10n.placementEnvironmentInitial,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _result(
                  title: _model == UnitPowerStateModel.preplacedLayout
                      ? l10n.placementCheckPreplacedPower
                      : l10n.placementPolicyPower,
                  text: valid ? powerText() : l10n.placementPolicyUnavailable,
                  issue: power?.issueCode,
                  provider: power?.providerId,
                  revision: power?.stateRevision,
                  point: power?.point,
                  busy: powerBusy,
                  keyName: 'power',
                  onLoad: selected && !powerBusy && powerSupported
                      ? () => _load(creep: false)
                      : null,
                ),
                if (_model == UnitPowerStateModel.initialMap && !powerSupported)
                  Text(
                    l10n.placementEnvironmentPowerCollectorUnavailable,
                    key: const Key('environment-power-collector-unavailable'),
                  ),
                const Divider(),
                _result(
                  title: l10n.placementEnvironmentInitialCreep,
                  text: valid ? creepText() : l10n.placementPolicyUnavailable,
                  issue: creep?.issueCode,
                  provider: creep?.providerId,
                  revision: creep?.stateRevision,
                  point: creep?.point,
                  busy: creepBusy,
                  keyName: 'creep',
                  onLoad:
                      selected &&
                          !creepBusy &&
                          controller.unitCreepStateGateway != null
                      ? () => _load(creep: true)
                      : null,
                ),
                if (controller.unitCreepStateGateway == null)
                  Text(
                    l10n.placementEnvironmentCollectorUnavailable,
                    key: const Key('environment-collector-unavailable'),
                  ),
                CheckboxListTile(
                  key: const Key('placement-check-creep'),
                  value: controller.state.checkCreep,
                  onChanged: (value) => controller.setCheckCreep(value!),
                  title: Text(l10n.placementCheckCreep),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.editorClose),
          ),
        ],
      );
    },
  );

  Widget _coordinate(
    TextEditingController value,
    String label,
    String keyName,
  ) => TextField(
    key: Key(keyName),
    controller: value,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(5),
    ],
    decoration: InputDecoration(labelText: label, suffixText: 'px'),
    onChanged: (_) => setState(() {}),
  );

  Widget _result({
    required String title,
    required String text,
    required String keyName,
    required bool busy,
    required VoidCallback? onLoad,
    String? issue,
    String? provider,
    String? revision,
    ({int x, int y})? point,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            SizedBox(
              width: 48,
              height: 48,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      key: Key('environment-load-$keyName'),
                      tooltip: l10n.placementEnvironmentRefresh,
                      onPressed: onLoad,
                      icon: const Icon(Icons.refresh),
                    ),
            ),
          ],
        ),
        Text(
          busy ? l10n.placementPolicyLoading : text,
          key: Key('environment-result-$keyName'),
        ),
        if (point != null)
          Text(
            'X ${point.x}, Y ${point.y} px',
            key: Key('environment-point-$keyName'),
          ),
        if (issue != null)
          Text(
            placementFailureText(l10n, issue),
            key: Key('environment-issue-$keyName'),
          ),
        if (provider != null)
          SelectableText(provider, key: Key('environment-provider-$keyName')),
        if (revision != null)
          SelectableText(revision, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
