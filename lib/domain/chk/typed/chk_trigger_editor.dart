import 'dart:typed_data';
import '../raw_chk_document.dart';
import 'chk_string_views.dart';

class TriggerArgument {
  const TriggerArgument(
    this.name,
    this.offset,
    this.width, {
    this.max = 0xffffffff,
    this.choices = const {},
    this.reference,
  });
  final String name;
  final int offset, width, max;
  final Map<int, String> choices;
  final String? reference;
}

class TriggerOpcode {
  const TriggerOpcode(this.id, this.name, this.arguments, {this.flags = 0});
  final int id, flags;
  final String name;
  final List<TriggerArgument> arguments;
}

abstract final class TriggerOpcodes {
  static const comparisons = {0: 'At least', 1: 'At most', 10: 'Exactly'};
  static const players = {
    0: 'Player 1',
    1: 'Player 2',
    2: 'Player 3',
    3: 'Player 4',
    4: 'Player 5',
    5: 'Player 6',
    6: 'Player 7',
    7: 'Player 8',
    8: 'Player 9',
    9: 'Player 10',
    10: 'Player 11',
    11: 'Player 12',
    13: 'Current player',
    14: 'Foes',
    15: 'Allies',
    16: 'Neutral players',
    17: 'All players',
    18: 'Force 1',
    19: 'Force 2',
    20: 'Force 3',
    21: 'Force 4',
    26: 'Non-allied victory players',
  };
  static const owners = {
    0: 'Player 1',
    1: 'Player 2',
    2: 'Player 3',
    3: 'Player 4',
    4: 'Player 5',
    5: 'Player 6',
    6: 'Player 7',
    7: 'Player 8',
    8: 'Player 9',
    9: 'Player 10',
    10: 'Player 11',
    11: 'Player 12',
    17: 'All players',
    18: 'Force 1',
    19: 'Force 2',
    20: 'Force 3',
    21: 'Force 4',
  };
  static const scores = {
    0: 'Total',
    1: 'Units',
    2: 'Buildings',
    3: 'Units and buildings',
    4: 'Kills',
    5: 'Razings',
    6: 'Kills and razings',
    7: 'Custom',
  };
  static const modifier = TriggerArgument(
    'Modifier',
    27,
    1,
    choices: {7: 'Set to', 8: 'Add', 9: 'Subtract'},
  );
  static const state = TriggerArgument(
    'State',
    27,
    1,
    choices: {4: 'Enable', 5: 'Disable', 6: 'Toggle'},
  );
  static const count = TriggerArgument('Count (0 = All)', 27, 1, max: 255);
  static const value = TriggerArgument('Amount', 20, 4);
  static const duration = TriggerArgument('Duration', 12, 4);
  static const dest = TriggerArgument(
    'Destination location ID',
    20,
    4,
    max: 255,
    reference: 'location',
  );
  static const score = TriggerArgument('Score', 24, 2, choices: scores);
  static const resource = TriggerArgument(
    'Resource',
    24,
    2,
    choices: resources,
  );
  static const cu = TriggerArgument(
    'Unit ID',
    12,
    2,
    max: 232,
    reference: 'unitGroup',
  );
  static const gu = TriggerArgument(
    'Unit ID',
    24,
    2,
    max: 232,
    reference: 'unitGroup',
  );
  static const sound = TriggerArgument(
    'Sound string ID',
    8,
    4,
    reference: 'string',
  );
  static const script = TriggerArgument(
    'AI script (4 characters)',
    20,
    4,
    reference: 'script',
  );
  static const resources = {0: 'Minerals', 1: 'Gas', 2: 'Minerals and gas'};
  static const cp = TriggerArgument('Player', 4, 4, choices: players);
  static const comparison = TriggerArgument(
    'Comparison',
    14,
    1,
    choices: comparisons,
  );
  static const amount = TriggerArgument('Amount', 8, 4);
  static const unit = TriggerArgument(
    'Unit ID',
    12,
    2,
    max: 227,
    reference: 'unit',
  );
  static const location = TriggerArgument(
    'Location ID',
    0,
    4,
    max: 255,
    reference: 'location',
  );
  static const ap = TriggerArgument('Player', 16, 4, choices: players);
  static const au = TriggerArgument(
    'Unit ID',
    24,
    2,
    max: 227,
    reference: 'unit',
  );
  static const text = TriggerArgument('String ID', 4, 4, reference: 'string');
  static const conditions = [
    TriggerOpcode(22, 'Always', []),
    TriggerOpcode(23, 'Never', []),
    TriggerOpcode(12, 'Elapsed time', [comparison, amount]),
    TriggerOpcode(1, 'Countdown timer', [comparison, amount]),
    TriggerOpcode(2, 'Command', [cp, comparison, amount, cu]),
    TriggerOpcode(3, 'Bring', [cp, comparison, amount, cu, location]),
    TriggerOpcode(4, 'Accumulate', [
      cp,
      comparison,
      amount,
      TriggerArgument('Resource', 16, 1, choices: resources),
    ]),
    TriggerOpcode(11, 'Switch', [
      TriggerArgument(
        'Switch ID (0–255)',
        16,
        1,
        max: 255,
        reference: 'switch',
      ),
      TriggerArgument('State', 14, 1, choices: {2: 'Set', 3: 'Cleared'}),
    ]),
    TriggerOpcode(5, 'Kills', [cp, comparison, amount, cu]),
    TriggerOpcode(6, 'Command most', [cu]),
    TriggerOpcode(7, 'Command most at', [cu, location]),
    TriggerOpcode(8, 'Most kills', [cu]),
    TriggerOpcode(9, 'Highest score', [
      TriggerArgument('Score', 16, 1, choices: scores),
    ]),
    TriggerOpcode(10, 'Most resources', [
      TriggerArgument('Resource', 16, 1, choices: resources),
    ]),
    TriggerOpcode(14, 'Opponents', [cp, comparison, amount]),
    TriggerOpcode(15, 'Deaths', [cp, comparison, amount, unit]),
    TriggerOpcode(16, 'Command least', [cu]),
    TriggerOpcode(17, 'Command least at', [cu, location]),
    TriggerOpcode(18, 'Least kills', [cu]),
    TriggerOpcode(19, 'Lowest score', [
      TriggerArgument('Score', 16, 1, choices: scores),
    ]),
    TriggerOpcode(20, 'Least resources', [
      TriggerArgument('Resource', 16, 1, choices: resources),
    ]),
    TriggerOpcode(21, 'Score', [
      cp,
      comparison,
      amount,
      TriggerArgument('Score', 16, 1, choices: scores),
    ]),
  ];
  static const actions = [
    TriggerOpcode(1, 'Victory', [], flags: 4),
    TriggerOpcode(2, 'Defeat', [], flags: 4),
    TriggerOpcode(3, 'Preserve trigger', [], flags: 4),
    TriggerOpcode(4, 'Wait (milliseconds)', [
      TriggerArgument('Milliseconds', 12, 4),
    ], flags: 4),
    TriggerOpcode(9, 'Display text', [text], flags: 4),
    TriggerOpcode(10, 'Center view', [location], flags: 4),
    TriggerOpcode(13, 'Set switch', [
      TriggerArgument(
        'Switch ID (0–255)',
        20,
        4,
        max: 255,
        reference: 'switch',
      ),
      TriggerArgument(
        'State',
        27,
        1,
        choices: {4: 'Set', 5: 'Clear', 6: 'Toggle', 11: 'Randomize'},
      ),
    ], flags: 4),
    TriggerOpcode(22, 'Kill unit', [ap, gu], flags: 20),
    TriggerOpcode(24, 'Remove unit', [ap, gu], flags: 20),
    TriggerOpcode(26, 'Set resources', [
      ap,
      TriggerArgument(
        'Modifier',
        27,
        1,
        choices: {7: 'Set to', 8: 'Add', 9: 'Subtract'},
      ),
      TriggerArgument('Amount', 20, 4),
      TriggerArgument('Resource', 24, 2, choices: resources),
    ], flags: 4),
    TriggerOpcode(44, 'Create unit', [
      ap,
      au,
      location,
      TriggerArgument('Count', 27, 1, max: 255),
    ], flags: 20),
    TriggerOpcode(47, 'Comment', [text], flags: 4),
    TriggerOpcode(5, 'Pause game', [], flags: 4),
    TriggerOpcode(6, 'Unpause game', [], flags: 4),
    TriggerOpcode(7, 'Transmission', [
      au,
      location,
      sound,
      duration,
      modifier,
      text,
    ], flags: 4),
    TriggerOpcode(8, 'Play WAV', [sound], flags: 4),
    TriggerOpcode(11, 'Create unit with properties', [
      ap,
      au,
      location,
      TriggerArgument('Count', 27, 1, max: 255),
      TriggerArgument(
        'Property slot ID',
        20,
        4,
        max: 64,
        reference: 'property',
      ),
    ], flags: 28),
    TriggerOpcode(12, 'Set mission objectives', [text], flags: 4),
    TriggerOpcode(14, 'Set countdown timer', [modifier, duration], flags: 4),
    TriggerOpcode(15, 'Run AI script', [script], flags: 4),
    TriggerOpcode(16, 'Run AI script at', [script, location], flags: 4),
    TriggerOpcode(17, 'Leaderboard control', [gu, text], flags: 20),
    TriggerOpcode(18, 'Leaderboard control at', [
      gu,
      location,
      text,
    ], flags: 20),
    TriggerOpcode(19, 'Leaderboard resources', [resource, text], flags: 4),
    TriggerOpcode(20, 'Leaderboard kills', [gu, text], flags: 20),
    TriggerOpcode(21, 'Leaderboard score', [score, text], flags: 4),
    TriggerOpcode(23, 'Kill unit at', [ap, gu, location, count], flags: 20),
    TriggerOpcode(25, 'Remove unit at', [ap, gu, location, count], flags: 20),
    TriggerOpcode(27, 'Set score', [ap, modifier, value, score], flags: 4),
    TriggerOpcode(28, 'Minimap ping', [location], flags: 4),
    TriggerOpcode(29, 'Talking portrait', [au, duration], flags: 20),
    TriggerOpcode(30, 'Mute unit speech', [], flags: 4),
    TriggerOpcode(31, 'Unmute unit speech', [], flags: 4),
    TriggerOpcode(32, 'Leaderboard computer players', [state], flags: 4),
    TriggerOpcode(33, 'Leaderboard goal control', [value, gu, text], flags: 20),
    TriggerOpcode(34, 'Leaderboard goal control at', [
      value,
      gu,
      location,
      text,
    ], flags: 20),
    TriggerOpcode(35, 'Leaderboard goal resources', [
      value,
      resource,
      text,
    ], flags: 4),
    TriggerOpcode(36, 'Leaderboard goal kills', [value, gu, text], flags: 20),
    TriggerOpcode(37, 'Leaderboard goal score', [value, score, text], flags: 4),
    TriggerOpcode(38, 'Move location', [
      TriggerArgument(
        'Location to move ID',
        0,
        4,
        max: 255,
        reference: 'location',
      ),
      ap,
      gu,
      TriggerArgument(
        'Search location ID',
        20,
        4,
        max: 255,
        reference: 'location',
      ),
    ], flags: 20),
    TriggerOpcode(39, 'Move unit', [ap, gu, location, dest, count], flags: 20),
    TriggerOpcode(40, 'Leaderboard greed', [value], flags: 4),
    TriggerOpcode(41, 'Set next scenario', [text], flags: 4),
    TriggerOpcode(42, 'Set doodad state', [state, ap, gu, location], flags: 20),
    TriggerOpcode(43, 'Set invincibility', [
      state,
      ap,
      gu,
      location,
    ], flags: 20),
    TriggerOpcode(45, 'Set deaths', [ap, modifier, value, au], flags: 20),
    TriggerOpcode(46, 'Order', [
      ap,
      gu,
      location,
      dest,
      TriggerArgument(
        'Order',
        27,
        1,
        choices: {0: 'Move', 1: 'Patrol', 2: 'Attack'},
      ),
    ], flags: 20),
    TriggerOpcode(48, 'Give units', [
      ap,
      gu,
      location,
      count,
      TriggerArgument('New owner', 20, 4, choices: players),
    ], flags: 20),
    TriggerOpcode(49, 'Modify hitpoints', [
      ap,
      gu,
      location,
      count,
      TriggerArgument('Percent', 20, 4, max: 100),
    ], flags: 20),
    TriggerOpcode(50, 'Modify energy', [
      ap,
      gu,
      location,
      count,
      TriggerArgument('Percent', 20, 4, max: 100),
    ], flags: 20),
    TriggerOpcode(51, 'Modify shields', [
      ap,
      gu,
      location,
      count,
      TriggerArgument('Percent', 20, 4, max: 100),
    ], flags: 20),
    TriggerOpcode(52, 'Modify resources', [
      ap,
      location,
      count,
      value,
    ], flags: 4),
    TriggerOpcode(53, 'Modify hangar count', [
      ap,
      gu,
      location,
      count,
      value,
    ], flags: 20),
    TriggerOpcode(54, 'Pause timer', [], flags: 4),
    TriggerOpcode(55, 'Unpause timer', [], flags: 4),
    TriggerOpcode(56, 'Draw', [], flags: 4),
    TriggerOpcode(57, 'Set alliance status', [
      ap,
      TriggerArgument(
        'Alliance',
        24,
        2,
        choices: {0: 'Enemy', 1: 'Ally', 2: 'Allied victory'},
      ),
    ], flags: 4),
  ];
  static TriggerOpcode? find(bool action, int id) {
    for (final opcode in action ? actions : conditions) {
      if (opcode.id == id) return opcode;
    }
    return null;
  }
}

final class ChkTrigger {
  ChkTrigger(List<int> bytes) : bytes = List.unmodifiable(bytes) {
    if (bytes.length != 2400 || bytes.any((b) => b < 0 || b > 255)) {
      throw const FormatException('TRIG records require 2400 bytes.');
    }
  }
  factory ChkTrigger.create() {
    final bytes = Uint8List(2400);
    bytes[15] = 23; // New triggers start with Never until explicitly edited.
    bytes[2372] = 1;
    return ChkTrigger(bytes);
  }
  final List<int> bytes;
  List<int> slot(bool action, int index) {
    RangeError.checkValueInInterval(index, 0, action ? 63 : 15);
    final size = action ? 32 : 20;
    final start = (action ? 320 : 0) + index * size;
    return bytes.sublist(start, start + size);
  }

  static int type(bool action, List<int> slot) => slot[action ? 26 : 15];
  static bool editable(bool action, List<int> slot) =>
      TriggerOpcodes.find(action, type(action, slot)) != null &&
      slot[action ? 30 : 18] == 0 &&
      slot[action ? 31 : 19] == 0 &&
      (!(type(action, slot) == (action ? 45 : 15)) ||
          (TriggerOpcodes.players.containsKey(
                ByteData.sublistView(
                  Uint8List.fromList(slot),
                ).getUint32(action ? 16 : 4, Endian.little),
              ) &&
              ByteData.sublistView(
                    Uint8List.fromList(slot),
                  ).getUint16(action ? 24 : 12, Endian.little) <
                  228));
  bool get enabled => bytes[2368] & 8 == 0;
  ChkTrigger withEnabled(bool enabled) => ChkTrigger(
    [...bytes]..[2368] = enabled ? bytes[2368] & ~8 : bytes[2368] | 8,
  );
  ChkTrigger withSlotEnabled(bool action, int index, bool enabled) {
    final next = slot(action, index);
    if (!editable(action, next)) {
      throw const FormatException('Unsupported slot is read-only.');
    }
    final offset = action ? 28 : 17;
    next[offset] = enabled ? next[offset] & ~2 : next[offset] | 2;
    return withSlot(action, index, next);
  }

  ChkTrigger moveSlot(bool action, int from, int to) {
    final a = slot(action, from), b = slot(action, to);
    return withSlot(action, from, b).withSlot(action, to, a);
  }

  ChkTrigger withOwner(int player, bool enabled) {
    if (!TriggerOpcodes.owners.containsKey(player)) {
      throw RangeError.value(player);
    }
    final next = Uint8List.fromList(bytes)..[2372 + player] = enabled ? 1 : 0;
    return ChkTrigger(next);
  }

  ChkTrigger withSlot(bool action, int index, List<int> replacement) {
    slot(action, index);
    final size = action ? 32 : 20;
    if (replacement.length != size ||
        replacement.any((b) => b < 0 || b > 255)) {
      throw const FormatException('Invalid trigger slot size.');
    }
    final next = Uint8List.fromList(bytes);
    next.setRange(
      (action ? 320 : 0) + index * size,
      (action ? 320 : 0) + (index + 1) * size,
      replacement,
    );
    return ChkTrigger(next);
  }

  static List<int> makeSlot(
    bool action,
    TriggerOpcode opcode,
    Map<String, int> values,
    RawChkDocument document, {
    List<int>? original,
  }) {
    if (TriggerOpcodes.find(action, opcode.id) != opcode) {
      throw const FormatException('Unsupported opcode.');
    }
    if (original != null &&
        (!editable(action, original) || type(action, original) != opcode.id)) {
      throw const FormatException('Unsupported slot must be preserved.');
    }
    final bytes = original == null
        ? Uint8List(action ? 32 : 20)
        : Uint8List.fromList(original);
    bytes[action ? 26 : 15] = opcode.id;
    if (original == null) bytes[action ? 28 : 17] = opcode.flags;
    final data = ByteData.sublistView(bytes);
    for (final arg in opcode.arguments) {
      final value = values[arg.name];
      if (value == null ||
          value < 0 ||
          value > arg.max ||
          (arg.choices.isNotEmpty && !arg.choices.containsKey(value))) {
        throw FormatException('Invalid ${arg.name}.');
      }
      if (arg.reference == 'location') {
        final sections = document.sections
            .where((s) => s.name == 'MRGN')
            .toList();
        if (sections.length != 1 ||
            sections.single.payload.length % 20 != 0 ||
            value < 1 ||
            value > sections.single.payload.length ~/ 20) {
          throw const FormatException('Location ID is unavailable.');
        }
      }
      if (arg.reference == 'unitGroup' && value == 228) {
        throw const FormatException('None is not a unit group.');
      }
      if (arg.reference == 'script' &&
          List.generate(
            4,
            (i) => (value >> (8 * i)) & 255,
          ).any((b) => b < 32 || b > 126)) {
        throw const FormatException(
          'AI script ID requires four printable ASCII characters.',
        );
      }
      if (arg.reference == 'property') {
        final sections = document.sections
            .where((s) => s.name == 'UPRP')
            .toList();
        if (value < 1 ||
            sections.length != 1 ||
            sections.single.payload.length != 1280) {
          throw const FormatException('Property slot is unavailable.');
        }
      }
      if (arg.reference == 'string') {
        final views = const ChkStringViewDecoder().decode(document);
        final hasExtended = document.sections.any((s) => s.name == 'STRx');
        final tables = hasExtended ? views.extendedTables : views.legacyTables;
        if (document.sections
                    .where((s) => s.name == (hasExtended ? 'STRx' : 'STR '))
                    .length !=
                1 ||
            tables.length != 1 ||
            tables.single.entryForId(value)?.isStructurallyValid != true) {
          throw const FormatException('String ID is unavailable or ambiguous.');
        }
      }
      switch (arg.width) {
        case 1:
          data.setUint8(arg.offset, value);
        case 2:
          data.setUint16(arg.offset, value, Endian.little);
        case 4:
          data.setUint32(arg.offset, value, Endian.little);
      }
    }
    return bytes;
  }

  static int argument(List<int> slot, TriggerArgument arg) {
    final data = ByteData.sublistView(Uint8List.fromList(slot));
    return switch (arg.width) {
      1 => data.getUint8(arg.offset),
      2 => data.getUint16(arg.offset, Endian.little),
      _ => data.getUint32(arg.offset, Endian.little),
    };
  }
}

final class ChkTriggers {
  static List<String> validationIssues(RawChkDocument document) {
    final issues = <String>[];
    final records = read(document).records;
    for (var r = 0; r < records.length; r++) {
      for (final action in [false, true]) {
        for (var s = 0; s < (action ? 64 : 16); s++) {
          final slot = records[r].slot(action, s);
          if (!ChkTrigger.editable(action, slot)) continue;
          final opcode = TriggerOpcodes.find(
            action,
            ChkTrigger.type(action, slot),
          )!;
          try {
            ChkTrigger.makeSlot(
              action,
              opcode,
              {
                for (final arg in opcode.arguments)
                  arg.name: ChkTrigger.argument(slot, arg),
              },
              document,
              original: slot,
            );
          } catch (e) {
            issues.add(
              'Trigger ${r + 1}, ${action ? 'action' : 'condition'} ${s + 1} (${opcode.name}): $e',
            );
          }
        }
      }
    }
    return issues;
  }

  ChkTriggers(this.sectionIndex, List<ChkTrigger> records)
    : records = List.unmodifiable(records);
  final int sectionIndex;
  final List<ChkTrigger> records;
  static ChkTriggers read(RawChkDocument document) {
    final indices = [
      for (var i = 0; i < document.sections.length; i++)
        if (document.sections[i].name == 'TRIG') i,
    ];
    if (indices.length != 1) {
      throw const FormatException(
        'Expected one TRIG section. Missing or duplicate sections are preserved without editing.',
      );
    }
    final bytes = document.sections[indices.single].payload;
    if (bytes.length % 2400 != 0) {
      throw const FormatException('Truncated TRIG section; editing blocked.');
    }
    return ChkTriggers(indices.single, [
      for (var i = 0; i < bytes.length; i += 2400)
        ChkTrigger(bytes.sublist(i, i + 2400)),
    ]);
  }

  static List<int> encode(List<ChkTrigger> records) => [
    for (final record in records) ...record.bytes,
  ];
}
