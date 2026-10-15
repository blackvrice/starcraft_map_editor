import '../chk/typed/chk_object_views.dart';

/// Caller-verified state tied to one immutable UNIT record. These facts are
/// not inferred from CHK presence, HP percentages, valid flags or sprites.
final class UnitPowerUnitState {
  const UnitPowerUnitState(
    this.unit, {
    this.exists,
    this.isCompleted,
    this.isEnabled,
  });

  final ChkUnitPlacement unit;
  final bool? exists;
  final bool? isCompleted;
  final bool? isEnabled;
}
