import '../../domain/placement/unit_power_catalog.dart';
import '../ports/unit_power_state_gateway.dart';

/// A point-in-time query, never permission to place or reuse after an edit.
final class UnitPowerInspection {
  const UnitPowerInspection.checked(
    UnitPowerCheck this.check, {
    required ({int x, int y}) this.point,
    required this.model,
    this.providerId,
    this.stateRevision,
  }) : issueCode = null;

  const UnitPowerInspection.refused(String this.issueCode)
    : check = null,
      point = null,
      model = null,
      providerId = null,
      stateRevision = null;

  const UnitPowerInspection.notApplicable()
    : check = UnitPowerCheck.notApplicable,
      point = null,
      issueCode = null,
      model = null,
      providerId = null,
      stateRevision = null;

  final UnitPowerCheck? check;
  final ({int x, int y})? point;
  final String? issueCode;
  final UnitPowerStateModel? model;
  final String? providerId, stateRevision;
}
