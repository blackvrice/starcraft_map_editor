/// Synchronized game-state rules. No source text, local-player predicates,
/// memory addresses or runtime object handles are accepted by this model.
enum EudResource { ore, gas }

enum EudComparison { atLeast, atMost, exactly }

enum EudResourceOperation { setTo, add, subtract }

enum EudRuleSchedule { once, periodic }

final class EudExecutionRule {
  EudExecutionRule({
    required this.id,
    required this.name,
    required this.player,
    required this.resource,
    required this.comparison,
    required this.threshold,
    required this.operation,
    required this.amount,
    this.schedule = EudRuleSchedule.once,
    this.interval = 24,
    this.enabled = true,
  }) {
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$').hasMatch(id) ||
        name.trim().isEmpty ||
        name.length > 120 ||
        player < 0 ||
        player > 7 ||
        threshold < 0 ||
        threshold > 0x7fffffff ||
        amount < 0 ||
        amount > 0x7fffffff ||
        interval < 12 ||
        interval > 86400) {
      throw const FormatException(
        'Invalid EUD execution rule: check name, player, values and interval (12–86400 cycles).',
      );
    }
  }

  final String id;
  final String name;

  /// Zero-based explicit player; never CurrentPlayer or LocalPlayer.
  final int player;
  final EudResource resource;
  final EudComparison comparison;
  final int threshold;
  final EudResourceOperation operation;
  final int amount;
  final EudRuleSchedule schedule;

  /// beforeTriggerExec invocations, not wall-clock milliseconds.
  final int interval;
  final bool enabled;

  String get writeTarget => '$player:${resource.name}';

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'player': player,
    'resource': resource.name,
    'comparison': comparison.name,
    'threshold': threshold,
    'operation': operation.name,
    'amount': amount,
    'schedule': schedule.name,
    'interval': interval,
    'enabled': enabled,
  };

  static EudExecutionRule fromJson(Object? value) {
    const keys = {
      'id',
      'name',
      'player',
      'resource',
      'comparison',
      'threshold',
      'operation',
      'amount',
      'schedule',
      'interval',
      'enabled',
    };
    if (value is! Map<String, dynamic> ||
        value.length != keys.length ||
        !keys.containsAll(value.keys) ||
        value['id'] is! String ||
        value['name'] is! String ||
        value['player'] is! int ||
        value['threshold'] is! int ||
        value['amount'] is! int ||
        value['interval'] is! int ||
        value['enabled'] is! bool) {
      throw const FormatException('Invalid EUD execution rule properties.');
    }
    T choice<T extends Enum>(String key, List<T> options) {
      for (final option in options) {
        if (option.name == value[key]) return option;
      }
      throw FormatException('Unsupported EUD execution rule $key.');
    }

    return EudExecutionRule(
      id: value['id'] as String,
      name: value['name'] as String,
      player: value['player'] as int,
      resource: choice('resource', EudResource.values),
      comparison: choice('comparison', EudComparison.values),
      threshold: value['threshold'] as int,
      operation: choice('operation', EudResourceOperation.values),
      amount: value['amount'] as int,
      schedule: choice('schedule', EudRuleSchedule.values),
      interval: value['interval'] as int,
      enabled: value['enabled'] as bool,
    );
  }
}
