import '../../domain/eud/eud_execution_rule.dart';
import '../../domain/eud/eud_rule_expression.dart';
import '../localization/l10n.dart';

/// Localized names and one-line sentences for EUD execution rules.
abstract final class EudRuleLabels {
  static String resource(AppLocalizations l10n, EudResource value) =>
      switch (value) {
        EudResource.ore => l10n.eudResMinerals,
        EudResource.gas => l10n.eudResGas,
      };

  static String comparison(AppLocalizations l10n, EudComparison value) =>
      switch (value) {
        EudComparison.atLeast => l10n.eudCmpAtLeast,
        EudComparison.atMost => l10n.eudCmpAtMost,
        EudComparison.exactly => l10n.eudCmpExactly,
      };

  static String operation(AppLocalizations l10n, EudResourceOperation value) =>
      switch (value) {
        EudResourceOperation.setTo => l10n.eudOpSetTo,
        EudResourceOperation.add => l10n.eudOpAdd,
        EudResourceOperation.subtract => l10n.eudOpSubtract,
      };

  static String schedule(AppLocalizations l10n, EudExecutionRule rule) =>
      rule.schedule == EudRuleSchedule.once
      ? l10n.eudRuleOnce
      : l10n.eudRuleEvery(rule.interval);

  static String action(AppLocalizations l10n, EudRuleAction value) =>
      switch (value) {
        EudRuleAction.variable => l10n.eudActVariable,
        EudRuleAction.minerals => l10n.eudActMinerals,
        EudRuleAction.gas => l10n.eudActGas,
        EudRuleAction.upgrade => l10n.eudActUpgrade,
        EudRuleAction.technology => l10n.eudActTechnology,
        EudRuleAction.location => l10n.eudActLocation,
        EudRuleAction.unitHp => l10n.eudActUnitHp,
        EudRuleAction.unitShields => l10n.eudActUnitShields,
        EudRuleAction.unitEnergy => l10n.eudActUnitEnergy,
        EudRuleAction.followUnit => l10n.eudActFollowUnit,
        EudRuleAction.text => l10n.eudActText,
        EudRuleAction.sound => l10n.eudActSound,
      };

  static String timing(AppLocalizations l10n, EudRuleTiming value) =>
      switch (value) {
        EudRuleTiming.beforeTriggers => l10n.eudTimingBefore,
        EudRuleTiming.afterTriggers => l10n.eudTimingAfter,
      };

  static String source(AppLocalizations l10n, EudValueSource value) =>
      switch (value) {
        EudValueSource.constant => l10n.eudSrcConstant,
        EudValueSource.variable => l10n.eudSrcVariable,
        EudValueSource.minerals => l10n.eudSrcMinerals,
        EudValueSource.gas => l10n.eudSrcGas,
        EudValueSource.upgrade => l10n.eudSrcUpgrade,
        EudValueSource.technology => l10n.eudSrcTechnology,
      };

  /// “When Minerals is at least 100 → add 50” for a basic resource rule, or
  /// the target action, id and timing for an extended rule.
  static String sentence(AppLocalizations l10n, EudExecutionRule rule) {
    final extension = rule.extension;
    if (extension != null) {
      return '${action(l10n, extension.action)} #${extension.target} · '
          '${timing(l10n, extension.timing)}';
    }
    final name = resource(l10n, rule.resource);
    final value = '${rule.threshold}';
    final condition = switch (rule.comparison) {
      EudComparison.atLeast => l10n.eudCmpAtLeastSentence(name, value),
      EudComparison.atMost => l10n.eudCmpAtMostSentence(name, value),
      EudComparison.exactly => l10n.eudCmpExactlySentence(name, value),
    };
    final amount = '${rule.amount}';
    final result = switch (rule.operation) {
      EudResourceOperation.setTo => l10n.eudOpSetToSentence(amount),
      EudResourceOperation.add => l10n.eudOpAddSentence(amount),
      EudResourceOperation.subtract => l10n.eudOpSubtractSentence(amount),
    };
    return l10n.eudRuleWhenThen(condition, result);
  }
}
