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
    13: 'Current player',
    17: 'All players',
    18: 'Force 1',
    19: 'Force 2',
    20: 'Force 3',
    21: 'Force 4',
  };
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
    TriggerOpcode(2, 'Command', [cp, comparison, amount, unit]),
    TriggerOpcode(3, 'Bring', [cp, comparison, amount, unit, location]),
    TriggerOpcode(4, 'Accumulate', [
      cp,
      comparison,
      amount,
      TriggerArgument('Resource', 16, 1, choices: resources),
    ]),
    TriggerOpcode(11, 'Switch', [
      TriggerArgument('Switch ID (0–255)', 16, 1, max: 255),
      TriggerArgument('State', 14, 1, choices: {2: 'Set', 3: 'Cleared'}),
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
      TriggerArgument('Switch ID (0–255)', 20, 4, max: 255),
      TriggerArgument(
        'State',
        27,
        1,
        choices: {4: 'Set', 5: 'Clear', 6: 'Toggle', 11: 'Randomize'},
      ),
    ], flags: 4),
    TriggerOpcode(22, 'Kill unit', [ap, au], flags: 20),
    TriggerOpcode(24, 'Remove unit', [ap, au], flags: 20),
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
      slot[action ? 31 : 19] == 0;
  ChkTrigger withOwner(int player, bool enabled) {
    RangeError.checkValueInInterval(player, 0, 7);
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
