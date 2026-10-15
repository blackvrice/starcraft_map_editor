import '../../domain/placement/unit_creep_catalog.dart';
import '../ports/unit_creep_state_gateway.dart';

/// A point-in-time positive requirement query, never permission to place.
final class UnitCreepInspection {
  const UnitCreepInspection.checked(
    UnitCreepCheck this.check, {
    required ({int x, int y}) this.point,
    required this.model,
    this.providerId,
    this.stateRevision,
  }) : issueCode = null;

  const UnitCreepInspection.refused(String this.issueCode)
    : check = null,
      point = null,
      model = null,
      providerId = null,
      stateRevision = null;

  const UnitCreepInspection.notApplicable()
    : check = UnitCreepCheck.notApplicable,
      point = null,
      issueCode = null,
      model = null,
      providerId = null,
      stateRevision = null;

  final UnitCreepCheck? check;
  final ({int x, int y})? point;
  final String? issueCode;
  final UnitCreepStateModel? model;
  final String? providerId, stateRevision;
}
