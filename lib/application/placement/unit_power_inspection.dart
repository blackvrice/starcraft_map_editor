import '../../domain/placement/unit_power_catalog.dart';

/// A point-in-time query, never permission to place or reuse after an edit.
final class UnitPowerInspection {
  const UnitPowerInspection.checked(
    UnitPowerCheck this.check, {
    required ({int x, int y}) this.point,
  }) : issueCode = null;

  const UnitPowerInspection.refused(String this.issueCode)
    : check = null,
      point = null;

  const UnitPowerInspection.notApplicable()
    : check = UnitPowerCheck.notApplicable,
      point = null,
      issueCode = null;

  final UnitPowerCheck? check;
  final ({int x, int y})? point;
  final String? issueCode;
}
