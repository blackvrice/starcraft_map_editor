import '../../domain/placement/unit_resource_distance_catalog.dart';

/// Inspection only: neither clear nor notApplicable authorizes placement.
final class UnitResourceDistanceInspection {
  const UnitResourceDistanceInspection.checked(
    UnitResourceDistanceCatalogCheck this.check, {
    required ({int x, int y}) this.point,
  }) : issueCode = null;

  const UnitResourceDistanceInspection.refused(String this.issueCode)
    : check = null,
      point = null;

  const UnitResourceDistanceInspection.notApplicable()
    : check = UnitResourceDistanceCatalogCheck.notApplicable,
      issueCode = null,
      point = null;

  final UnitResourceDistanceCatalogCheck? check;
  final String? issueCode;
  final ({int x, int y})? point;
}
