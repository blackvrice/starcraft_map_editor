import 'package:flutter/material.dart';

import '../../application/placement/placement_catalog_controller.dart';
import '../../application/placement/placement_policy_support.dart';
import '../localization/l10n.dart';

class PlacementPolicyDialog extends StatelessWidget {
  const PlacementPolicyDialog({required this.controller, super.key});
  final PlacementCatalogController controller;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: controller.changes,
    builder: (context, _) {
      final l10n = context.l10n;
      final support = controller.placementPolicySupport;
      return AlertDialog(
        key: const Key('placement-policy-dialog'),
        title: Text(l10n.placementPolicySupport),
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
                for (final rule in PlacementPolicyRule.values)
                  Padding(
                    key: ValueKey('placement-policy-${rule.name}'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(switch (rule) {
                            PlacementPolicyRule.recordSafety =>
                              l10n.placementPolicyRecordSafety,
                            PlacementPolicyRule.buildingAlignment =>
                              l10n.placementBuildingTileAlignment,
                            PlacementPolicyRule.unitOverlap =>
                              l10n.placementPolicyUnitOverlap,
                            PlacementPolicyRule.terrain =>
                              l10n.placementPolicyTerrain,
                            PlacementPolicyRule.resourceDistance =>
                              l10n.placementPolicyResourceDistance,
                            PlacementPolicyRule.power =>
                              l10n.placementPolicyPower,
                            PlacementPolicyRule.creep =>
                              l10n.placementPolicyCreep,
                            PlacementPolicyRule.eudRuntime =>
                              l10n.placementPolicyEudRuntime,
                            PlacementPolicyRule.gameAcceptance =>
                              l10n.placementPolicyGameAcceptance,
                          }),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Text(switch (support[rule]!) {
                            PlacementPolicySupportStatus.enforced =>
                              l10n.placementPolicyEnforced,
                            PlacementPolicySupportStatus.enabled =>
                              l10n.placementPolicyEnabled,
                            PlacementPolicySupportStatus.skipped =>
                              l10n.placementPolicySkipped,
                            PlacementPolicySupportStatus.notApplicable =>
                              l10n.placementPolicyNotApplicable,
                            PlacementPolicySupportStatus.loading =>
                              l10n.placementPolicyLoading,
                            PlacementPolicySupportStatus.unavailable =>
                              l10n.placementPolicyUnavailable,
                            PlacementPolicySupportStatus.notImplemented =>
                              l10n.placementPolicyNotImplemented,
                            PlacementPolicySupportStatus.acceptancePending =>
                              l10n.placementPolicyAcceptancePending,
                          }),
                        ),
                      ],
                    ),
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
}
