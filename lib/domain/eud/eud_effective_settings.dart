import '../chk/raw_chk_document.dart';
import '../chk/typed/chk_unit_settings_editor.dart';
import '../chk/typed/chk_upgrade_settings_editor.dart';
import '../chk/typed/chk_tech_settings_editor.dart';
import 'eud_field_manifest.dart';
import 'eud_project.dart';

enum EudBaselineSource {
  unverifiedMap,
  chk,
  gameDefault,
  unavailable,
  notInChk,
}

/// A proposed value under the declarative policy, never a runtime result.
final class EudEffectiveSetting {
  const EudEffectiveSetting({
    required this.override,
    required this.baselineSource,
    this.baselineValue,
    this.baselineDetail,
    this.plannedValue,
  });
  final EudOverride override;
  final EudBaselineSource baselineSource;
  final int? baselineValue;
  final String? baselineDetail;
  final Object? plannedValue;
}

abstract final class EudEffectiveSettings {
  /// Only supply a document whose saved snapshot matches the project binding.
  static List<EudEffectiveSetting> resolve(
    EudProject project, {
    RawChkDocument? verifiedDocument,
  }) {
    ChkUnitSettings? units;
    String? readError;
    if (verifiedDocument != null &&
        project.overrides.any((o) => o.field == 'unit.maxShield')) {
      try {
        units = const ChkUnitSettingsEditor().read(verifiedDocument);
      } on StateError catch (error) {
        readError = error.message.toString();
      }
    }
    final projectValid = project.validationIssues.isEmpty;
    return List.unmodifiable(
      project.overrides.map((item) {
        var source = EudBaselineSource.unverifiedMap;
        int? value;
        String? detail;
        final field = EudFieldManifest.find(item.field);
        final valid =
            field?.validate(item.targetId, item.value) == null && field != null;
        if (verifiedDocument != null) {
          if (!valid) {
            source = EudBaselineSource.unavailable;
            detail = 'Invalid or unsupported field / target / value';
          } else if (item.field != 'unit.maxShield') {
            source = field.overlapsChk
                ? EudBaselineSource.unavailable
                : EudBaselineSource.notInChk;
            detail = field.overlapsChk
                ? 'CHK baseline reader is not connected for this field'
                : 'Game DAT value has not been loaded';
            if (field.overlapsChk) {
              (source, value, detail) = _costBaseline(item, verifiedDocument);
            }
          } else if (units == null) {
            source = EudBaselineSource.unavailable;
            detail = readError;
          } else {
            final flag = units.value(
              item.targetId,
              ChkUnitSettingField.useDefault,
            );
            detail = '${units.sectionName}, useDefault=$flag';
            if (flag == 0) {
              source = EudBaselineSource.chk;
              value = units.value(item.targetId, ChkUnitSettingField.shields);
            } else if (flag == 1) {
              source = EudBaselineSource.gameDefault;
            } else {
              source = EudBaselineSource.unavailable;
            }
          }
        }
        return EudEffectiveSetting(
          override: item,
          baselineSource: source,
          baselineValue: value,
          baselineDetail: detail,
          plannedValue:
              projectValid &&
                  valid &&
                  source != EudBaselineSource.unverifiedMap &&
                  source != EudBaselineSource.unavailable
              ? item.value
              : null,
        );
      }),
    );
  }

  static (EudBaselineSource, int?, String) _costBaseline(
    EudOverride item,
    RawChkDocument document,
  ) {
    const upgrades = {
      'upgrade.mineralCostBase': ChkUpgradeField.minerals,
      'upgrade.mineralCostFactor': ChkUpgradeField.mineralFactor,
      'upgrade.gasCostBase': ChkUpgradeField.gas,
      'upgrade.gasCostFactor': ChkUpgradeField.gasFactor,
      'upgrade.timeCostBase': ChkUpgradeField.time,
      'upgrade.timeCostFactor': ChkUpgradeField.timeFactor,
    };
    const techs = {
      'tech.mineralCost': ChkTechField.minerals,
      'tech.gasCost': ChkTechField.gas,
      'tech.timeCost': ChkTechField.time,
      'tech.energyCost': ChkTechField.energy,
    };
    try {
      int flag;
      int cost;
      String section;
      if (upgrades.containsKey(item.field)) {
        final settings = const ChkUpgradeSettingsEditor().read(document);
        flag = settings.value((
          item.targetId,
          null,
          ChkUpgradeField.useDefault,
        ));
        cost = settings.value((item.targetId, null, upgrades[item.field]!));
        section = settings.costName;
      } else if (techs.containsKey(item.field)) {
        final settings = const ChkTechSettingsEditor().read(document);
        flag = settings.value((item.targetId, null, ChkTechField.useDefault));
        cost = settings.value((item.targetId, null, techs[item.field]!));
        section = settings.costName;
      } else {
        return (
          EudBaselineSource.unavailable,
          null,
          'Global DAT maximum differs from CHK map/player research limits; no single baseline',
        );
      }
      return (
        switch (flag) {
          0 => EudBaselineSource.chk,
          1 => EudBaselineSource.gameDefault,
          _ => EudBaselineSource.unavailable,
        },
        flag == 0 ? cost : null,
        '$section, useDefault=$flag',
      );
    } on StateError catch (error) {
      return (EudBaselineSource.unavailable, null, error.toString());
    } on RangeError catch (error) {
      return (EudBaselineSource.unavailable, null, error.toString());
    }
  }
}
