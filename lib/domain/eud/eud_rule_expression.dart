/// All dynamic values are unsigned 16-bit, saturating after each calculation.
/// Variables are 16 synchronized slots, initialized to zero on each game start.
enum EudValueSource { constant, variable, minerals, gas, upgrade, technology }

final class EudRuleValue {
  EudRuleValue({
    this.source = EudValueSource.constant,
    this.index = 0,
    this.player = 0,
    this.factor = 1,
    this.offset = 0,
  }) {
    final maximum = switch (source) {
      EudValueSource.constant => 65535,
      EudValueSource.variable => 15,
      EudValueSource.minerals || EudValueSource.gas => 0,
      EudValueSource.upgrade => 60,
      EudValueSource.technology => 43,
    };
    if (index < 0 ||
        index > maximum ||
        player < 0 ||
        player > 7 ||
        factor < 0 ||
        factor > 255 ||
        offset < -65535 ||
        offset > 65535) {
      throw const FormatException('Invalid bounded rule value.');
    }
  }
  final EudValueSource source;
  final int index, player, factor, offset;
  Map<String, Object> toJson() => {
    'source': source.name,
    'index': index,
    'player': player,
    'factor': factor,
    'offset': offset,
  };
  static EudRuleValue decode(Object? raw) {
    final m = ruleObject(raw, {
      'source',
      'index',
      'player',
      'factor',
      'offset',
    });
    return EudRuleValue(
      source: ruleEnum(m['source'], EudValueSource.values),
      index: ruleInt(m['index']),
      player: ruleInt(m['player']),
      factor: ruleInt(m['factor']),
      offset: ruleInt(m['offset']),
    );
  }
}

enum EudRuleAction {
  variable,
  minerals,
  gas,
  upgrade,
  technology,
  location,
  unitHp,
  unitShields,
  unitEnergy,
  followUnit,
  text,
  sound,
}

enum EudRuleTiming { beforeTriggers, afterTriggers }

/// One synchronized condition and one typed action. Local display targeting
/// is available only to text/sound, never to conditions or game-state writes.
final class EudRuleExtension {
  EudRuleExtension({
    required this.action,
    required this.left,
    required this.right,
    required this.value,
    this.target = 0,
    this.timing = EudRuleTiming.beforeTriggers,
    this.text = '',
    Iterable<EudRuleValue> coordinates = const [],
    this.unitType = 0,
  }) : coordinates = List.unmodifiable(coordinates) {
    final maximum = switch (action) {
      EudRuleAction.variable => 15,
      EudRuleAction.upgrade => 60,
      EudRuleAction.technology => 43,
      EudRuleAction.location || EudRuleAction.followUnit => 255,
      EudRuleAction.sound => 65535,
      _ => 0,
    };
    if (target < 0 ||
        target > maximum ||
        unitType < 0 ||
        unitType > 227 ||
        (usesLocation && (target == 0 || target == 64)) ||
        (action == EudRuleAction.sound && target == 0) ||
        text.length > 240 ||
        text.contains('\u0000') ||
        (action == EudRuleAction.location
            ? this.coordinates.length != 4
            : this.coordinates.isNotEmpty)) {
      throw const FormatException(
        'Invalid rule action target, coordinates or text.',
      );
    }
  }
  final EudRuleAction action;
  final EudRuleValue left, right, value;
  final int target, unitType;
  final EudRuleTiming timing;
  final String text;

  /// x, y, width, height in pixels; runtime clamped to the map dimensions.
  final List<EudRuleValue> coordinates;
  bool get localDisplay =>
      action == EudRuleAction.text || action == EudRuleAction.sound;
  bool get usesUnit => {
    EudRuleAction.unitHp,
    EudRuleAction.unitShields,
    EudRuleAction.unitEnergy,
    EudRuleAction.followUnit,
  }.contains(action);
  bool get usesLocation =>
      action == EudRuleAction.location || action == EudRuleAction.followUnit;
  Iterable<EudRuleValue> get values => [left, right, value, ...coordinates];
  Map<String, Object> toJson() => {
    'action': action.name,
    'left': left.toJson(),
    'right': right.toJson(),
    'value': value.toJson(),
    'target': target,
    'timing': timing.name,
    'text': text,
    'unitType': unitType,
    'coordinates': coordinates.map((v) => v.toJson()).toList(),
  };
  static EudRuleExtension decode(Object? raw) {
    final m = ruleObject(raw, {
      'action',
      'left',
      'right',
      'value',
      'target',
      'timing',
      'text',
      'unitType',
      'coordinates',
    });
    if (m['coordinates'] is! List ||
        (m['coordinates'] as List).length > 4 ||
        m['text'] is! String) {
      throw const FormatException('Invalid extended rule.');
    }
    return EudRuleExtension(
      action: ruleEnum(m['action'], EudRuleAction.values),
      left: EudRuleValue.decode(m['left']),
      right: EudRuleValue.decode(m['right']),
      value: EudRuleValue.decode(m['value']),
      target: ruleInt(m['target']),
      timing: ruleEnum(m['timing'], EudRuleTiming.values),
      text: m['text'] as String,
      unitType: ruleInt(m['unitType']),
      coordinates: (m['coordinates'] as List).map(EudRuleValue.decode),
    );
  }
}

Map<String, dynamic> ruleObject(Object? raw, Set<String> keys) {
  if (raw is! Map<String, dynamic> ||
      raw.length != keys.length ||
      !keys.containsAll(raw.keys)) {
    throw const FormatException('Unknown or missing rule properties.');
  }
  return raw;
}

int ruleInt(Object? raw) {
  if (raw is! int) throw const FormatException('Rule integer required.');
  return raw;
}

T ruleEnum<T extends Enum>(Object? raw, List<T> values) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  throw const FormatException('Unsupported rule choice.');
}
