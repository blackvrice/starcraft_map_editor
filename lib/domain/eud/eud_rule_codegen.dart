import 'dart:convert';
import 'eud_execution_rule.dart';
import 'eud_rule_expression.dart';

/// Emits only closed, typed operations. Text is always a quoted literal.
abstract final class EudRuleCodegen {
  static String value(EudRuleValue v) {
    final base = switch (v.source) {
      EudValueSource.constant => '${v.index}',
      EudValueSource.variable => '_er_vars[${v.index}]',
      EudValueSource.minerals => 'TrgPlayer(${v.player}).ore',
      EudValueSource.gas => 'TrgPlayer(${v.player}).gas',
      EudValueSource.upgrade => 'Upgrade(${v.index})[${v.player}]',
      EudValueSource.technology => 'Tech(${v.index})[${v.player}]',
    };
    return '_er_value($base, ${v.factor}, ${v.offset})';
  }

  static List<String> declarations(List<EudExecutionRule> rules) => [
    'from eudplib import EUDFunc, EUDReturn, EUDElse, EUDLoopUnit2, CUnit, f_setloc, f_println, f_getuserplayerid, f_getcurpl, f_setcurpl, PlayWAV, GetChkTokenized',
    '_er_vars = [EUDVariable(0) for _ in range(16)]',
    '_er_dimensions = GetChkTokenized().getsection("DIM ")',
    '_er_width = int.from_bytes(_er_dimensions[:2], "little") * 32',
    '_er_height = int.from_bytes(_er_dimensions[2:4], "little") * 32',
    for (final r in rules.where((r) => r.enabled && r.extension != null)) ...[
      if (r.extension!.usesLocation)
        'assert len(GetChkTokenized().getsection("MRGN")) >= ${r.extension!.target * 20}, "Unavailable rule location"',
      if (r.extension!.action == EudRuleAction.sound) ...[
        '_er_wavs = GetChkTokenized().getsection("WAV ")',
        'assert ${r.extension!.target} in [int.from_bytes(_er_wavs[n:n+4], "little") for n in range(0, len(_er_wavs), 4)], "Unregistered rule sound"',
      ],
    ],
    ...helpers.split('\n'),
    for (var i = 0; i < rules.length; i++)
      if (rules[i].enabled && (rules[i].extension?.usesUnit ?? false))
        ...unitHelper(rules[i], i),
  ];

  static const helpers = '''@EUDFunc
def _er_limit(value, maximum):
    result = EUDVariable()
    result << value
    if EUDIf()(result > maximum):
        result << maximum
    EUDEndIf()
    EUDReturn(result)

def _er_value(value, factor, offset):
    result = EUDVariable()
    result << _er_limit(value, 65535) * factor
    if offset < 0:
        if EUDIf()(result >= -offset):
            result -= -offset
        if EUDElse()():
            result << 0
        EUDEndIf()
    else:
        result += offset
    return _er_limit(result, 65535)
''';

  static List<String> rule(EudExecutionRule r, int i) {
    final e = r.extension!;
    final state = '_editor_rule_$i';
    final compare = ['>=', '<=', '=='][r.comparison.index];
    final lines = <String>[
      '    _run_$i = EUDVariable()',
      '    _run_$i << 0',
      if (r.schedule == EudRuleSchedule.periodic)
        '    DoActions($state.AddNumber(1))',
      '    if EUDIf()($state.${r.schedule == EudRuleSchedule.once ? 'Exactly(0)' : 'AtLeast(${r.interval})'}):',
      if (r.schedule == EudRuleSchedule.periodic)
        '        DoActions($state.SetNumber(0))',
      '        if EUDIf()(${value(e.left)} $compare ${value(e.right)}):',
      '            _run_$i << 1',
      '        EUDEndIf()',
      '    EUDEndIf()',
    ];
    if (e.usesUnit) {
      lines.add('    _success_$i = _er_unit_$i(_run_$i, ${value(e.value)})');
      if (r.schedule == EudRuleSchedule.once) {
        lines.addAll([
          '    if EUDIf()(_success_$i == 1):',
          '        DoActions($state.SetNumber(1))',
          '    EUDEndIf()',
        ]);
      }
    } else {
      lines.add('    if EUDIf()(_run_$i == 1):');
      // Latch is synchronized even for a locally displayed action.
      if (r.schedule == EudRuleSchedule.once) {
        lines.add('        DoActions($state.SetNumber(1))');
      }
      lines.addAll(action(r).map((s) => '        $s'));
      lines.add('    EUDEndIf()');
    }
    return lines;
  }

  static List<String> action(EudExecutionRule r) {
    final e = r.extension!;
    final v = value(e.value);
    final modifier = ['SetTo', 'Add', 'Subtract'][r.operation.index];
    switch (e.action) {
      case EudRuleAction.variable:
        return ['_er_vars[${e.target}] << $v'];
      case EudRuleAction.minerals:
      case EudRuleAction.gas:
        return [
          'DoActions(SetResources(${r.player}, $modifier, $v, ${e.action == EudRuleAction.minerals ? 'Ore' : 'Gas'}))',
        ];
      case EudRuleAction.upgrade:
        return [
          'Upgrade(${e.target})[${r.player}] = _er_limit($v, Upgrade(${e.target}).maxLevel)',
        ];
      case EudRuleAction.technology:
        return ['Tech(${e.target})[${r.player}] = _er_limit($v, 1)'];
      case EudRuleAction.location:
        return [
          '_x = _er_limit(${value(e.coordinates[0])}, _er_width)',
          '_y = _er_limit(${value(e.coordinates[1])}, _er_height)',
          '_right = _er_limit(_x + ${value(e.coordinates[2])}, _er_width)',
          '_bottom = _er_limit(_y + ${value(e.coordinates[3])}, _er_height)',
          'f_setloc(${e.target}, _x, _y, _right, _bottom)',
        ];
      case EudRuleAction.text:
      case EudRuleAction.sound:
        return [
          // Evaluate synchronized values before entering a local branch.
          if (e.action == EudRuleAction.text) '_text_value = $v',
          'if EUDIf()(f_getuserplayerid() == ${r.player}):',
          '    _old_cp = f_getcurpl()',
          '    f_setcurpl(${r.player})',
          if (e.action == EudRuleAction.text)
            '    f_println(${jsonEncode('${e.text.replaceAll('{', '{{').replaceAll('}', '}}')} {}')}, _text_value)'
          else
            '    DoActions(PlayWAV(${e.target}))',
          '    f_setcurpl(_old_cp)',
          'EUDEndIf()',
        ];
      default:
        throw StateError('Unit actions use guarded instance access.');
    }
  }

  static List<String> unitHelper(EudExecutionRule r, int i) {
    final e = r.extension!;
    final member = switch (e.action) {
      EudRuleAction.unitHp => 'hp',
      EudRuleAction.unitShields => 'shield',
      _ => 'energy',
    };
    return [
      '_er_binding_$i = [EUDVariable(0) for _ in range(3)]',
      '@EUDFunc',
      'def _er_unit_$i(active, amount):',
      '    status, identity, generation = _er_binding_$i',
      '    found, success = EUDVariable(0), EUDVariable(0)',
      '    found << 0',
      '    success << 0',
      '    if EUDIf()(status <= 1):',
      '        for ptr, epd in EUDLoopUnit2():',
      '            unit = CUnit(epd)',
      '            if EUDIf()([unit.owner == ${r.player}, unit.unitType == ${e.unitType}, unit.order >= 1, unit.hp >= 1]):',
      '                if EUDIf()([status == 0, active == 1]):',
      '                    identity << epd',
      '                    generation << unit.uniquenessIdentifier',
      '                    status << 1',
      '                EUDEndIf()',
      '                if EUDIf()([status == 1, identity == epd, generation == unit.uniquenessIdentifier]):',
      '                    found << 1',
      '                    if EUDIf()(active == 1):',
      if (e.action == EudRuleAction.followUnit)
        '                        f_setloc(${e.target}, _er_limit(unit.posX, _er_width), _er_limit(unit.posY, _er_height))'
      else ...[
        if (e.action == EudRuleAction.unitHp) ...[
          '                        amount = _er_limit(amount * 256, TrgUnit(${e.unitType}).maxHp)',
          '                        if EUDIf()(amount >= 1):',
          '                            unit.$member = amount',
          '                            success << 1',
          '                        EUDEndIf()',
        ] else if (e.action == EudRuleAction.unitShields) ...[
          '                        if EUDIf()(TrgUnit(${e.unitType}).hasShield == 1):',
          '                            unit.$member = _er_limit(amount, TrgUnit(${e.unitType}).maxShield) * 256',
          '                            success << 1',
          '                        EUDEndIf()',
        ] else
          '                        unit.$member = _er_limit(amount, 250) * 256',
      ],
      if (e.action == EudRuleAction.unitEnergy ||
          e.action == EudRuleAction.followUnit)
        '                        success << 1',
      '                    EUDEndIf()',
      '                EUDEndIf()',
      '            EUDEndIf()',
      '        if EUDIf()([status == 1, found == 0]):',
      '            status << 2',
      '        EUDEndIf()',
      '    EUDEndIf()',
      '    EUDReturn(success)',
    ];
  }
}
