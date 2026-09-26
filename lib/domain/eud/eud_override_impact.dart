import '../placement/unit_weapon_references.dart';
import 'eud_field_manifest.dart';
import 'eud_project.dart';

/// Static DAT reachability, not a guarantee of runtime attack behavior.
final class EudOverrideImpact {
  EudOverrideImpact._(this.error, List<int>? direct, List<int>? subunit)
    : directUnits = direct == null ? null : List.unmodifiable(direct),
      subunitUnits = subunit == null ? null : List.unmodifiable(subunit);

  final EudFieldError? error;
  // Null means unavailable, while an empty list means verified no references.
  final List<int>? directUnits;
  final List<int>? subunitUnits;

  factory EudOverrideImpact.analyze(
    EudOverride override, {
    UnitWeaponIndex? references,
  }) {
    final error = EudFieldManifest.validate(
      override.field,
      override.targetId,
      override.value,
    );
    if (error != null) return EudOverrideImpact._(error, null, null);
    final field = EudFieldManifest.find(override.field)!;
    if (field.table == EudTable.unit) {
      return EudOverrideImpact._(null, [override.targetId], []);
    }
    if (field.table != EudTable.weapon) {
      return EudOverrideImpact._(null, null, null);
    }
    return EudOverrideImpact._(
      null,
      references?.directUsers(override.targetId),
      references?.subunitUsers(override.targetId),
    );
  }
}
