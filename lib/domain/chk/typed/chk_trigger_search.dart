import 'dart:convert';
import '../raw_chk_document.dart';
import 'chk_resource_editor.dart';
import 'chk_trigger_editor.dart';

final class TriggerReferenceHit {
  const TriggerReferenceHit(
    this.record,
    this.action,
    this.slot,
    this.opcode,
    this.argument,
    this.value,
    this.editable,
  );
  final int record, slot, value;
  final bool action, editable;
  final TriggerOpcode opcode;
  final TriggerArgument argument;
}

/// Index only documented opcode layouts, never infer fields in unknown slots.
final class ChkTriggerSearch {
  ChkTriggerSearch(
    this.document, {
    this.briefing = false,
    String Function(bool, int)? opcodeLabel,
  }) {
    records = ChkTriggers.read(document, briefing: briefing).records;
    final texts = <int, String>{};
    try {
      for (final e in ChkResourceEditor.table(document).entries) {
        if (e.rawBytes != null) {
          texts[e.stringId] = utf8.decode(e.rawBytes!, allowMalformed: true);
        }
      }
    } on FormatException {
      // Searching opcodes remains available without an unambiguous string table.
    }
    final refs = <TriggerReferenceHit>[];
    final labels = <String>[];
    final types = <Set<(bool, int)>>[];
    for (var r = 0; r < records.length; r++) {
      final record = records[r];
      final label = StringBuffer('${r + 1} ');
      final recordTypes = <(bool, int)>{};
      for (final owner in TriggerOpcodes.owners.entries) {
        if (record.bytes[2372 + owner.key] != 0) label.write('${owner.value} ');
      }
      for (final action in briefing ? [true] : [false, true]) {
        for (var s = 0; s < (action ? 64 : 16); s++) {
          final slot = record.slot(action, s);
          if (slot.every((b) => b == 0)) continue;
          recordTypes.add((action, ChkTrigger.type(action, slot)));
          final op = TriggerOpcodes.find(
            action,
            ChkTrigger.type(action, slot),
            briefing: briefing,
          );
          if (op == null) {
            label.write('opcode ${ChkTrigger.type(action, slot)} ');
            continue;
          }
          label.write('${op.name} ');
          if (opcodeLabel != null) {
            label.write('${opcodeLabel(action, op.id)} ');
          }
          for (final arg in op.arguments) {
            final value = ChkTrigger.argument(slot, arg);
            label.write('${arg.name} $value ${arg.choices[value] ?? ''} ');
            if (arg.reference != null) {
              refs.add(
                TriggerReferenceHit(
                  r,
                  action,
                  s,
                  op,
                  arg,
                  value,
                  ChkTrigger.editable(action, slot, briefing: briefing),
                ),
              );
              if (arg.reference == 'string') {
                label.write('${texts[value] ?? ''} ');
              }
            }
          }
        }
      }
      labels.add(label.toString().toLowerCase());
      types.add(Set.unmodifiable(recordTypes));
    }
    references = List.unmodifiable(refs);
    _labels = List.unmodifiable(labels);
    _types = List.unmodifiable(types);
  }

  final RawChkDocument document;
  final bool briefing;
  late final List<ChkTrigger> records;
  late final List<TriggerReferenceHit> references;
  late final List<String> _labels;
  late final List<Set<(bool, int)>> _types;
  static const replaceable = [
    'location',
    'string',
    'unit',
    'unitGroup',
    'switch',
    'property',
  ];

  List<int> find(
    String query, {
    String? reference,
    int? id,
    int? owner,
    bool? enabled,
    bool? action,
    int? opcode,
  }) {
    final words = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final matching = reference == null
        ? null
        : references
              .where(
                (h) =>
                    h.argument.reference == reference &&
                    (id == null || h.value == id),
              )
              .map((h) => h.record)
              .toSet();
    bool recordMatches(int index) {
      final r = records[index];
      if (enabled != null && r.enabled != enabled) return false;
      if (owner != null &&
          (owner < 0 || owner >= 28 || r.bytes[2372 + owner] == 0)) {
        return false;
      }
      if ((opcode != null || action != null) &&
          !_types[index].any(
            (t) =>
                (action == null || t.$1 == action) &&
                (opcode == null || t.$2 == opcode),
          )) {
        return false;
      }
      return true;
    }

    return [
      for (var i = 0; i < records.length; i++)
        if ((matching == null || matching.contains(i)) &&
            recordMatches(i) &&
            words.every(_labels[i].contains))
          i,
    ];
  }

  TriggerReplacementPreview replace({
    required Set<int> selected,
    required String reference,
    required int from,
    required int to,
  }) {
    if (!replaceable.contains(reference)) throw ArgumentError.value(reference);
    if (from < 0 || to < 0) {
      throw const FormatException('Reference IDs must be nonnegative.');
    }
    for (final index in selected) {
      RangeError.checkValidIndex(index, records);
    }
    var count = 0, skipped = 0;
    final changed = <int>{};
    final next = records.toList();
    for (final h in references) {
      if (!selected.contains(h.record) ||
          h.argument.reference != reference ||
          h.value != from ||
          from == to) {
        continue;
      }
      if (!h.editable) {
        skipped++;
        continue;
      }
      final record = next[h.record], slot = record.slot(h.action, h.slot);
      // Validate every argument against the same snapshot before exposing Apply.
      final replacement = ChkTrigger.makeSlot(
        h.action,
        h.opcode,
        {
          for (final arg in h.opcode.arguments)
            arg.name: identical(arg, h.argument)
                ? to
                : ChkTrigger.argument(slot, arg),
        },
        document,
        original: slot,
        briefing: briefing,
      );
      next[h.record] = record.withSlot(h.action, h.slot, replacement);
      changed.add(h.record);
      count++;
    }
    return TriggerReplacementPreview(
      List.unmodifiable(next),
      count,
      Set.unmodifiable(changed),
      skipped,
    );
  }
}

final class TriggerReplacementPreview {
  const TriggerReplacementPreview(
    this.records,
    this.replacements,
    this.changedRecords,
    this.skipped,
  );
  final List<ChkTrigger> records;
  final int replacements, skipped;
  final Set<int> changedRecords;
}
