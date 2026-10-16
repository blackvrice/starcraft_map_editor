import '../../eud/eud_dat_snapshot.dart';
import 'chk_unit_settings_editor.dart';
import 'chk_upgrade_settings_editor.dart';
import 'chk_tech_settings_editor.dart';

/// Read-only map/DAT resolution; runtime and EUD patches are deliberately absent.
abstract final class ChkSettingsDefaults {
  static const unitKeys = <ChkUnitSettingField, String>{
    ChkUnitSettingField.hitpoints: 'unit.hitpoints',
    ChkUnitSettingField.shields: 'unit.maxShield',
    ChkUnitSettingField.armor: 'unit.armor',
    ChkUnitSettingField.buildTime: 'unit.buildTime',
    ChkUnitSettingField.minerals: 'unit.minerals',
    ChkUnitSettingField.gas: 'unit.gas',
  };
  static const upgradeKeys = <ChkUpgradeField, String>{
    ChkUpgradeField.minerals: 'upgrade.mineralCostBase',
    ChkUpgradeField.mineralFactor: 'upgrade.mineralCostFactor',
    ChkUpgradeField.gas: 'upgrade.gasCostBase',
    ChkUpgradeField.gasFactor: 'upgrade.gasCostFactor',
    ChkUpgradeField.time: 'upgrade.timeCostBase',
    ChkUpgradeField.timeFactor: 'upgrade.timeCostFactor',
  };
  static const techKeys = <ChkTechField, String>{
    ChkTechField.minerals: 'tech.mineralCost',
    ChkTechField.gas: 'tech.gasCost',
    ChkTechField.time: 'tech.timeCost',
    ChkTechField.energy: 'tech.energyCost',
  };
  static int? unit(EudDatSnapshot? dat, int id, ChkUnitSettingField field) {
    if (field == ChkUnitSettingField.shields &&
        ![0, 1].contains(dat?.raw('unit.hasShield', id))) {
      return null;
    }
    if (field == ChkUnitSettingField.shields &&
        dat?.raw('unit.hasShield', id) == 0) {
      return 0;
    }
    return dat?.raw(unitKeys[field] ?? '', id);
  }

  static T? expected<T>({
    required int? mode,
    required T? stored,
    required T? baseline,
  }) => switch (mode) {
    0 => stored,
    1 => baseline,
    _ => null,
  };
}
