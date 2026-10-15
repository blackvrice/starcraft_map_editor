import '../chk/typed/chk_object_views.dart';

/// State tied to one immutable UNIT record and qualified by the caller's model.
/// Actual completion/activation is not inferred from CHK, HP or valid flags.
/// Explicit layout projections must remain labelled as projections by callers.
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
